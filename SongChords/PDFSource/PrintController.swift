//
//  PrintController.swift
//  SongChords
//
//  Created by Peter Wichert on 08.01.24.
//

import SwiftUI
import PDFKit
import SwiftData

protocol PrintDelegateBase {
    func createPDF() -> URL?
}

class PrintSongDelegate: NSObject, PrintDelegateBase {
    let userSettings = UserSettings()
    let song: Song
    
    init?(songID: PersistentIdentifier, modelContainer: ModelContainer) async {
        let modelContext = ModelContext(modelContainer)
        
        // bei fetchSong() nicht die Task-Variante, weil asynchron evtl. zu spät fertig ist und songRepresentation überschreibt
        guard let song = Song.fetchSong(with: songID, in: modelContext) else { return nil }
        self.song = song
        
        await SongTaskManager.shared.processSongInBackground(srcText: song.srcText, transpose: song.transpose, showHeader: song.showHeader, showText: song.showText, userSettings: userSettings, forPrinting: true)
        
        // warten, bis fertig
        let _ =  await SongTaskManager.shared.manager.waitUntilFinished()
    }
    
    func createPDF() -> URL? {
        return songToPdf(userSettings: userSettings)
    }
    
    func songToPdf(userSettings: UserSettings) -> URL? {
        let mgr = SongTaskManager.shared.representationHolder.directiveManager
        let margins = EdgeInsets(top: userSettings.margintop, leading: userSettings.marginleft, bottom: userSettings.marginbottom, trailing: userSettings.marginright)
        let pdfConfiguration = PDFConfiguration(mediaBox: userSettings.mediabox, margins: margins, columns: mgr.columns, scale: userSettings.printingscale / 100.0)
        guard let pdfGenerator = try? PDFGenerator(config: pdfConfiguration, userSettings: userSettings) else { return nil }
        
        let darkColor = Color(red: 0.15, green: 0.15, blue: 0.15)
        let lightColor = Color(red: 0.90, green: 0.90, blue: 0.90)
        
        pdfGenerator.startPDF()
        
        let title = mgr.getDirective("title") ?? song.title
        if !title.isEmpty {
            pdfGenerator.draw(Text(title).padding(.bottom, userSettings.linespacingpdf).font(.system(size: userSettings.chordsizepdf+4, weight: .bold, design: .rounded)))
        }
                
        pdfGenerator.markColumnTop()
        
        // Funktionssammler
        var rowEvents: [() -> Void] = []
        
        let rows = SongTaskManager.shared.representationHolder.rowsForPrinting
        for rowContent in rows {
            // function je nach row.rowEvent sammeln und bei nächster zeile ablegen
            // die Rows mit newpage/columnbreak erscheinen nicht mehr, wie in DetailView()
            switch rowContent.rowEvent {
            case .newpage: rowEvents.append(pdfGenerator.forceNewPage)
            case .columnbreak: rowEvents.append(pdfGenerator.forceColumnBreak)
            case .none:
                for rowEvent in rowEvents { rowEvent() }
                rowEvents = []

                pdfGenerator.draw(RowView(song: song, modelContext: nil, globals: nil, audioPlayer: nil, autoScroll: false, darkColor: darkColor, lightColor: lightColor, rowContent: rowContent, forPrinting: true, currentSectionID: nil))
            }
        }
        
        pdfGenerator.endPDF()
        
        return pdfGenerator.url
    }
}

class PrintSetlistDelegate: NSObject, PrintDelegateBase {
    let userSettings = UserSettings()
    let playlist: PlayList

    init(playlist: PlayList) {
        self.playlist = playlist
    }
    
    init?(playlistID: PersistentIdentifier, modelContainer: ModelContainer) {
        let modelContext = ModelContext(modelContainer)
        guard let playlist = PlayList.fetchPlaylist(with: playlistID, in: modelContext) else { return nil }
        self.playlist = playlist
    }

    func createPDF() -> URL? {
        return setlistToPDF(playlist: playlist, userSettings: userSettings)
    }
        
    func setlistToPDF(playlist: PlayList, userSettings: UserSettings) -> URL? {
        // 2-spaltig
        let margins = EdgeInsets(top: userSettings.margintop, leading: userSettings.marginleft, bottom: userSettings.marginbottom, trailing: userSettings.marginright)
        let pdfConfiguration = PDFConfiguration(mediaBox: userSettings.mediabox, margins: margins, columns: 2, scale: userSettings.printingscale / 100.0)
        guard let pdfGenerator = try? PDFGenerator(config: pdfConfiguration, userSettings: userSettings) else { return nil }
                
        pdfGenerator.startPDF()
        
        let title = playlist.title
        if !title.isEmpty {
            pdfGenerator.draw(Text(title).padding(.bottom, userSettings.linespacingpdf * 2.0).font(.system(size: userSettings.chordsizepdf+4, weight: .bold, design: .rounded)))
        }
        
        pdfGenerator.markColumnTop()
        
        var cnt = 1
        for song in (playlist.songs ?? []).sorted(by: { a,b in a.seq < b.seq }) {
            pdfGenerator.draw(Text("\(cnt).  \(song.title)").padding(.bottom, userSettings.linespacingpdf).font(.system(size: userSettings.txtsizepdf+4, weight: .semibold, design: .rounded)))
            
            cnt += 1
        }
        
        pdfGenerator.endPDF()
        return pdfGenerator.url
    }
}

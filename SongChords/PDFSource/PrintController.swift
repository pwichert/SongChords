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
    func createPDF(paperSize: CGRect) -> URL?
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
    
    // nur, um eine andere URL als beim Drucken zu haben. Sicher ist sicher.
    func createViewPDF(paperSize: CGRect) -> URL? {
        return songToPdf(userSettings: userSettings, paperSize: paperSize, viewURL: true)
    }
        
    func createPDF(paperSize: CGRect) -> URL? {
        return songToPdf(userSettings: userSettings, paperSize: paperSize)
    }
        
    func songToPdf(userSettings: UserSettings, paperSize: CGRect, viewURL: Bool = false) -> URL? {
        
        #if false
        // zum Testen
        do {
            let gen = try PDFGenerator(userSettings: userSettings, mediaBox: paperSize, cols: 1)
            
            gen.drawTest(col: 0, view: Text("1234567").font(.system(size: userSettings.chordsize+4, weight: .bold, design: .rounded)))
            
            return gen.url
        } catch { print(error.localizedDescription) ; return nil}
        #else
        
        do {
            let mgr = SongTaskManager.shared.representationHolder.directiveManager

            let darkColor = Color(red: 0.15, green: 0.15, blue: 0.15)
            let lightColor = Color(red: 0.90, green: 0.90, blue: 0.90)

            let gen = try PDFGenerator(userSettings: userSettings, mediaBox: paperSize, cols: mgr.columns, viewURL: viewURL)
            gen.startPDF()
            
            let title = mgr.getDirective("title") ?? song.title
            if !title.isEmpty {
                gen.draw(view: Text(title).font(.system(size: userSettings.chordsizepdf+4, weight: .bold, design: .rounded)))
            }

            gen.draw(view: Color.clear.padding(.bottom, 2))
            gen.setColumnTop()
            
            // Funktionssammler
            var f: [() -> Void] = []
            
            for row in SongTaskManager.shared.representationHolder.rowsForPrinting {
                // function je nach row.rowEvent sammeln und bei nächster zeile ablegen
                // die Rows mit newpage/columnbreak erscheinen nicht mehr, wie in DetailView()
                switch row.event {
                case .newpage: f.append(gen.setNewPage)
                case .columnbreak: f.append(gen.setColumnBreak)
                case .none:
                    gen.draw(view: RowView(id: row.id, darkColor: darkColor, lightColor: lightColor, content: row, events: f, forPrinting: true))
                    f = []
                }
            }
            
            try gen.endPDF()
            return gen.url
        } catch {
            print(error.localizedDescription)
            return nil
        }
        #endif
    }
}

class PrintSetlistDelegate: NSObject, PrintDelegateBase {
    let userSettings = UserSettings()
    let playlist: PlayList
    
    init?(playlistID: PersistentIdentifier, modelContainer: ModelContainer) {
        let modelContext = ModelContext(modelContainer)
        guard let playlist = PlayList.fetchPlaylist(with: playlistID, in: modelContext) else { return nil }
        self.playlist = playlist
    }

    func createPDF(paperSize: CGRect) -> URL? {
        return setlistToPDF(playlist: playlist, userSettings: userSettings, paperSize: paperSize)
    }
        
    func setlistToPDF(playlist: PlayList, userSettings: UserSettings, paperSize: CGRect) -> URL? {
        do {
            // 2-spaltig
            let gen = try PDFGenerator(userSettings: userSettings, mediaBox: paperSize, cols: 2)
            gen.startPDF()
            
            gen.draw(view: Text(playlist.title).font(.system(size: userSettings.txtsizepdf+8, weight: .bold, design: .rounded))
                .padding(.bottom, userSettings.txtsizepdf+8))
            
            gen.setColumnTop()
            let topPadding: CGFloat = 8

            var cnt = 1
            for song in (playlist.songs ?? []).sorted(by: { a,b in a.seq < b.seq }) {
                gen.draw(view: Text("\(cnt).  \(song.title)").font(.system(size: userSettings.txtsizepdf+4, weight: .semibold, design: .rounded)).padding(.top, topPadding))
                
                cnt += 1
            }
            
            try gen.endPDF()
            return gen.url
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}

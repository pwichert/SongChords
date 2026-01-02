//
//  PrintController.swift
//  SongChords
//
//  Created by Peter Wichert on 08.01.24.
//

import SwiftUI
import PDFKit
import SwiftData

#if os(macOS)
protocol UIPrintInteractionControllerDelegate {}
#endif

protocol PrintDelegateBase {
    func createPDF(paperSize: CGRect) -> URL?
}

class PrintSongDelegate: NSObject, PrintDelegateBase, UIPrintInteractionControllerDelegate {
    let userSettings = UserSettings()
    let song: Song
    let representationHolder = RepresentationHolder()
    
    init?(songID: PersistentIdentifier, modelContainer: ModelContainer) async {
        let modelContext = ModelContext(modelContainer)
        
        // bei fetchSong() nicht die Task-Variante, weil asynchron evtl. zu spät fertig ist und songRepresentation überschreibt
        guard let song = Song.fetchSong(with: songID, in: modelContext) else { return nil }
        self.song = song
        
        SongTaskManager.shared.processSongInBackground(representationHolder: representationHolder, srcText: song.srcText, transpose: song.transpose, showHeader: song.showHeader, showText: song.showText, userSettings: userSettings, forPrinting: true)
        // warten, bis fertig
        let _ = await SongTaskManager.shared.processingTask?.result
    }
    
    // nur, um eine andere URL als beim Drucken zu haben. Sicher ist sicher.
    func createViewPDF(paperSize: CGRect) -> URL? {
        return songToPdf(userSettings: userSettings, paperSize: paperSize, viewURL: true)
    }
        
    func createPDF(paperSize: CGRect) -> URL? {
        return songToPdf(userSettings: userSettings, paperSize: paperSize)
    }
    
#if os(iOS)
    #if false
    // Es gibt scheinbar keine passende Funktion, um die Seitengröße für den Druckdialog im Preview anpassen zu können...??
    func printInteractionControllerWillStartJobx(_ printInteractionController: UIPrintInteractionController) {
        print("printInteractionControllerWillStartJob")

        let paper = printInteractionController.printPaper
        let paperSize = paper?.paperSize
        print(paperSize ?? "nix")
        
        if let paperSize = paperSize {
            let url = songToPdf(userSettings: userSettings, paperSize: CGRect(origin: .zero, size: paperSize))
            printInteractionController.printingItem = url
        }
    }
    #endif
#endif
    
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
            let mgr = representationHolder.directiveManager

            let darkColor = Color(red: 0.15, green: 0.15, blue: 0.15)
            let lightColor = Color(red: 0.85, green: 0.85, blue: 0.85)

            let gen = try PDFGenerator(userSettings: userSettings, mediaBox: paperSize, cols: mgr.columns, viewURL: viewURL)
            gen.startPDF()
            
            let title = mgr.getDirective("title") ?? song.title
            if !title.isEmpty {
                gen.draw(view: Text(title).font(.system(size: userSettings.chordsizepdf+4, weight: .bold, design: .rounded)))
            }

            gen.draw(view: Color.clear.padding(.bottom, 2))
            gen.setColumnTop()
            
            #if true
            for row in representationHolder.rows {
                // function je nach row.rowEvent festlegen
                let f: (() -> Void)? = switch row.rowEvent {
                    case .newpage: gen.setNewPage
                    case .columnbreak: gen.setColumnBreak
                    case .none: nil
                }
                gen.draw(view: RowView(id: row.id, darkColor: darkColor, lightColor: lightColor, model: row, rowEvent: f, forPrinting: true))
            }
            #else
            for section in songRepresentation.sections {
                if section.isNewPage { gen.setNewPage() }

                if song.showHeader && section.name.trimmingCharacters(in: .whitespaces).count > 0 {
                    gen.draw(col: section.col, view:
                                SectionHeaderView(section: section, lightColor: Color.init(red: 0.85, green: 0.85, blue: 0.85), darkColor: Color.init(red: 0.15, green: 0.15, blue: 0.15))
                        .font(Font(userSettings.headerPDFUIFont))
                        .padding(EdgeInsets(top: topPadding, leading: 0, bottom: 0, trailing: 0)))
                }
                
                // siehe SongView, soll die gleiche Logik abbilden
                for line in section.splittedLines {
                    if line.onNewPage { gen.setNewPage() }
                                        
                    if userSettings.hidechords && line.texts.isEmpty && !line.chords.isEmpty { continue }
                    
                    var lineSpacing = userSettings.linespacingpdf

                    if line.chords.isEmpty && line.texts.isEmpty {
                        // Leerzeile
                        gen.draw(col: line.col, view: Text(" ").font(Font(userSettings.txtPDFUIFont))
                            .padding(EdgeInsets(top: lineSpacing, leading: 0, bottom: 0, trailing: 0)))
                    } else if userSettings.hidechords {
                        if song.showText {
                            gen.draw(col: line.col, view: Text(line.plainText).font(Font(userSettings.txtPDFUIFont))
                                .padding(EdgeInsets(top: lineSpacing, leading: 0, bottom: 0, trailing: 0)))
                        }
                    } else {
                        if song.showText {
                            if !line.chords.isEmpty {
                                gen.draw(col: line.col, view: ChordsLineView(line: line, lightColor: Color.init(red: 0.90, green: 0.90, blue: 0.90), darkColor: Color.init(red: 0.15, green: 0.15, blue: 0.15)).font(Font(userSettings.chordPDFUIFont))
                                    .padding(EdgeInsets(top: lineSpacing, leading: 0, bottom: 0, trailing: 0)))
                                
                                // nur der erste von ChordsLineView oder TextsLineView soll linespacen
                                lineSpacing = 0
                            }
                        } else {
                            if !line.chords.isEmpty {
                                gen.draw(col: line.col, view: ChordsPlainView(line: line, lightColor: Color.init(red: 0.90, green: 0.90, blue: 0.90), darkColor: Color.init(red: 0.15, green: 0.15, blue: 0.15)).font(Font(userSettings.chordPDFUIFont))
                                    .padding(EdgeInsets(top: lineSpacing, leading: 0, bottom: 0, trailing: 0)))
                                
                                // nur der erste von ChordsLineView oder TextsLineView soll linespacen
                                lineSpacing = 0
                            }
                        }
                        if song.showText {
                            if !line.texts.isEmpty {
                                gen.draw(col: line.col, view: TextsLineView(line: line).font(Font(userSettings.txtPDFUIFont))
                                    .padding(EdgeInsets(top: lineSpacing, leading: 0, bottom: 0, trailing: 0)))
                            }
                        }
                    }
                }
                
                topPadding = 8
            }
            #endif
            
            try gen.endPDF()
            return gen.url
        } catch {
            print(error.localizedDescription)
            return nil
        }
        #endif
    }
}

class PrintSetlistDelegate: NSObject, PrintDelegateBase, UIPrintInteractionControllerDelegate {
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
    
#if os(iOS)
    #if false
    // Es gibt scheinbar keine passende Funktion, um die Seitengröße für den Druckdialog im Preview anpassen zu können...??
    func printInteractionControllerWillStartJob(_ printInteractionController: UIPrintInteractionController) {
        let paper = printInteractionController.printPaper
        let paperSize = paper?.paperSize
        
        if let paperSize = paperSize {
            let url = setlistToPDF(playlist: playlist, userSettings: userSettings, paperSize: CGRect(origin: .zero, size: paperSize))
            printInteractionController.printingItem = url
        }
    }
    #endif
#endif
    
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

//class PrintController {
//    static func onPrint(title: String, delegate: UIPrintInteractionControllerDelegate) {
//        
//        let defaultPaper = MediaBoxes.getBox(name: UserSettings().mediabox)
//        
//#if os(iOS)
//        // UIPrintInfo contains information about the print job
//        let printInfo = UIPrintInfo(dictionary: nil)
//        printInfo.outputType = .general
//        printInfo.jobName = title
//        printInfo.orientation = UIPrintInfo.Orientation.portrait
//
//        // UIPrintInteractionController presents a user interface and manages the printing
//        let printController = UIPrintInteractionController.shared
//        let delegate = delegate
//        printController.delegate = delegate
//        printController.printInfo = printInfo
//
//        let url = (delegate as! PrintDelegateBase).createPDF(paperSize: defaultPaper)
//        
//        if let url = url {
//            printController.printingItem = url
//            
//            // Present print controller like usual view controller. Also completionHandler is available if needed.
//            printController.present(animated: true)
//        }
//#endif
//        
//#if os(macOS)
//        let printInfo = NSPrintInfo.shared
//        printInfo.orientation = NSPrintInfo.PaperOrientation.portrait
//        printInfo.isHorizontallyCentered = false
//        printInfo.isVerticallyCentered = false
//        printInfo.horizontalPagination = NSPrintInfo.PaginationMode.fit
//        printInfo.verticalPagination = NSPrintInfo.PaginationMode.fit
//        printInfo.leftMargin = 0
//        printInfo.rightMargin = 0
//        printInfo.topMargin = 0
//        printInfo.bottomMargin = 0
//
//        let url = (delegate as! PrintDelegateBase).createPDF(paperSize: defaultPaper)
//                
//        if let url = url {
//            let pdfDoc = PDFDocument(url: url)!
//            
//            let po = pdfDoc.printOperation(for: printInfo, scalingMode: .pageScaleNone, autoRotate: false)!
//            po.showsPrintPanel = true
//            po.jobTitle = title
//            po.showsProgressPanel = true
//            po.printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
//            po.printPanel.options.insert(NSPrintPanel.Options.showsOrientation)
//
//            #if true
//            if po.run() {
//                print("In Print completion")
//            }
//            #else
//            po.runModal(for: NSApplication.shared.mainWindow!, delegate: delegate, didRun: nil, contextInfo: nil)
//            #endif
//        }
//#endif
//    }
//}

//class delegate: NSObject { }

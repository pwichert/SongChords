//
//  PrintController.swift
//  SongChords
//
//  Created by Peter Wichert on 08.01.24.
//

import SwiftUI
import PDFKit

#if os(macOS)
protocol UIPrintInteractionControllerDelegate {}
#endif

@MainActor
protocol PrintDelegateBase {
    func createPDF(paperSize: CGRect) -> URL?
}

@MainActor
class PrintSongDelegate: NSObject, PrintDelegateBase, UIPrintInteractionControllerDelegate {
    let viewModel: ViewModel
    let song: Song
    
    init(viewModel: ViewModel, song: Song) {
        self.viewModel = viewModel
        self.song = song
    }
    
    // nur, um eine andere URL als beim Drucken zu haben Sicher ist sicher.
    func createViewPDF(paperSize: CGRect) -> URL? {
        return songToPdf(viewModel: viewModel, song: song, paperSize: paperSize, viewURL: true)
    }
        
    func createPDF(paperSize: CGRect) -> URL? {
        return songToPdf(viewModel: viewModel, song: song, paperSize: paperSize)
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
            let url = songToPdf(viewModel: viewModel, song: song, paperSize: CGRect(origin: .zero, size: paperSize))
            printInteractionController.printingItem = url
        }
    }
    #endif
#endif
    
    func songToPdf(viewModel: ViewModel, song: Song, paperSize: CGRect, viewURL: Bool = false) -> URL? {
        
        #if false
        // zum Testen
        do {
            let gen = try PDFGenerator(viewModel: viewModel, mediaBox: paperSize, cols: 1)
            
            gen.drawTest(col: 0, view: Text("1234567").font(.system(size: viewModel.chordsize+4, weight: .bold, design: .rounded)))
            
            return gen.url
        } catch { print(error.localizedDescription) ; return nil}
        #else
        
        do {
            let songRepresentation = song.createSongRepresentation(viewModel: viewModel, forPrinting: true)!
            let mgr = songRepresentation.directiveManager
            let cols = mgr.columns

            let gen = try PDFGenerator(viewModel: viewModel, mediaBox: paperSize, cols: cols, viewURL: viewURL)
            gen.startPDF()
            
            var topPadding: CGFloat = 0
            let title = mgr.getDirective("title") ?? song.title
            if !title.isEmpty {
                gen.draw(col: 0, view: Text(title).font(.system(size: viewModel.chordsize+4, weight: .bold, design: .rounded)))
                topPadding = 8
            }
            
            for (dir,title) in [
                (mgr.getDirective("subtitle"), ""),
                (mgr.getDirective("artist"), "Artist: "),
                (mgr.getDirective("album"), "Album: "),
                (mgr.getDirective("composer"), "Composer: "),
                (mgr.getDirective("year"), "Year: "),
                (mgr.getDirective("copyright"), "Copyright: "),
                (mgr.getDirective("tempo"), "Tempo: "),
                (mgr.getDirective("time"), "Time: "),
                (mgr.getDirective("duration"), "Duration: ")
            ] {
                if let dir = dir {
                    gen.draw(col: 0, view: Text("\(title)\(dir)").font(.system(size: viewModel.chordsizepdf, weight: .bold, design: .rounded)).padding(.top, topPadding))
                    topPadding = 3.5
                }
            }

            gen.draw(col: 0, view: Color.clear.padding(.bottom, 2))
            gen.setColumnTop()
            
            topPadding = 0
            
            for section in songRepresentation.sections {
                gen.draw(col: section.col, view:
                            SectionHeaderView(section: section)
                            .font(Font(viewModel.headerPDFUIFont))
                            .padding(EdgeInsets(top: topPadding, leading: 0, bottom: 4, trailing: 0)))
                                
                for line in section.splittedLines {
                    if line.onNewPage { gen.setNewPage() }
                    if line.chords.isEmpty && line.texts.isEmpty {
                        // Leerzeile
                        gen.draw(col: line.col, view: Text(" ").font(Font(viewModel.txtPDFUIFont)))
                    } else {
                        gen.draw(col: line.col, view: ChordsLineView(line: line).font(Font(viewModel.chordPDFUIFont)))
                        gen.draw(col: line.col, view: TextsLineView(line: line).font(Font(viewModel.txtPDFUIFont)))
                    }
                }
                
                topPadding = 8
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

@MainActor
class PrintSetlistDelegate: NSObject, PrintDelegateBase, UIPrintInteractionControllerDelegate {
    let viewModel: ViewModel
    let playlist: PlayList
    
    init(viewModel: ViewModel, playlist: PlayList) {
        self.viewModel = viewModel
        self.playlist = playlist
    }

    func createPDF(paperSize: CGRect) -> URL? {
        return setlistToPDF(playlist: playlist, viewModel: viewModel, paperSize: paperSize)
    }
    
#if os(iOS)
    #if false
    // Es gibt scheinbar keine passende Funktion, um die Seitengröße für den Druckdialog im Preview anpassen zu können...??
    func printInteractionControllerWillStartJob(_ printInteractionController: UIPrintInteractionController) {
        let paper = printInteractionController.printPaper
        let paperSize = paper?.paperSize
        
        if let paperSize = paperSize {
            let url = setlistToPDF(playlist: playlist, viewModel: viewModel, paperSize: CGRect(origin: .zero, size: paperSize))
            printInteractionController.printingItem = url
        }
    }
    #endif
#endif
    
    func setlistToPDF(playlist: PlayList, viewModel: ViewModel, paperSize: CGRect) -> URL? {
        do {
            // 2-spaltig
            let gen = try PDFGenerator(viewModel: viewModel, mediaBox: paperSize, cols: 2)
            gen.startPDF()
            
            gen.draw(col: 0, view: Text(playlist.title).font(.system(size: viewModel.txtsizepdf+6, weight: .bold, design: .rounded))
                .padding(.bottom, viewModel.chordsize))
            
            let topPadding: CGFloat = 8

            var cnt = 1
            for song in (playlist.songs ?? []).sorted(by: { a,b in a.seq < b.seq }) {
                gen.draw(col: 0, view: Text("\(cnt).  \(song.title)").font(.system(size: viewModel.txtsizepdf+4, weight: .semibold, design: .rounded)).padding(.top, topPadding))
                
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

@MainActor
class PrintController {
    static func onPrint(viewModel: ViewModel, title: String, delegate: UIPrintInteractionControllerDelegate) {
        
        let defaultPaper = MediaBoxes.getBox(name: viewModel.mediabox)
        
#if os(iOS)
        // UIPrintInfo contains information about the print job
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = title
        printInfo.orientation = UIPrintInfo.Orientation.portrait

        // UIPrintInteractionController presents a user interface and manages the printing
        let printController = UIPrintInteractionController.shared
        let delegate = delegate
        printController.delegate = delegate
        printController.printInfo = printInfo

        let url = (delegate as! PrintDelegateBase).createPDF(paperSize: defaultPaper)
        
        if let url = url {
            printController.printingItem = url
            
            // Present print controller like usual view controller. Also completionHandler is available if needed.
            printController.present(animated: true)
        }
#endif
        
#if os(macOS)
        let printInfo = NSPrintInfo.shared
        printInfo.orientation = NSPrintInfo.PaperOrientation.portrait
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.horizontalPagination = NSPrintInfo.PaginationMode.fit
        printInfo.verticalPagination = NSPrintInfo.PaginationMode.fit
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0

        let url = (delegate as! PrintDelegateBase).createPDF(paperSize: defaultPaper)
                
        if let url = url {
            let pdfDoc = PDFDocument(url: url)!
            
            let po = pdfDoc.printOperation(for: printInfo, scalingMode: .pageScaleNone, autoRotate: false)!
            po.showsPrintPanel = true
            po.jobTitle = title
            po.showsProgressPanel = true
            po.printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
            po.printPanel.options.insert(NSPrintPanel.Options.showsOrientation)

            #if true
            if po.run() {
                print("In Print completion")
            }
            #else
            po.runModal(for: NSApplication.shared.mainWindow!, delegate: delegate, didRun: nil, contextInfo: nil)
            #endif
        }
#endif
    }
}


class delegate: NSObject { }

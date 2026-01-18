//
//  PDFGeneratorII.swift
//  SongChords
//
//  Created by Peter Wichert on 14.01.26.
//

/*
PDFGenerator (Facade)
 ├─ PDFDocumentContext   (CGContext + Pages)
 ├─ PDFLayoutEngine      (Spalten, Umbrüche, Positionen)
 ├─ PDFRenderer          (SwiftUI → CGContext)
 └─ PDFConfiguration     (Paper, Margins, Scale)
*/

import SwiftUI
import OSLog

enum PDFLog {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PDF", category: "PDF")
    static func debug(_ msg: String) {
    #if DEBUG
        logger.debug("\(msg, privacy: .public)")
    #endif
    }
}

enum PaperSize: String, CaseIterable {
    case a5
    case a4
    case a3
    case usLetter
    case usLegal
    case usTabloid
    case usExecutive
    
    var displayName: String {
        switch self {
        case .a4: return "A4"
        case .a5: return "A5"
        case .a3: return "A3"
        case .usLetter: return "US Letter"
        case .usLegal: return "US Legal"
        case .usTabloid: return "US Tabloid"
        case .usExecutive: return "US Executive"
        }
    }
    
    static func from(displayName: String) -> PaperSize? {
        allCases.first {
            $0.displayName.caseInsensitiveCompare(displayName) == .orderedSame
        }
    }
}

class MediaBoxes {
    // 72 dpi
    
    static func box(for size: PaperSize) -> CGRect {
        switch size {
        case .a5: return CGRect(origin: .zero, size: .init(width: 420, height: 595))
        case .a4: return CGRect(origin: .zero, size: .init(width: 595, height: 842))
        case .a3: return CGRect(origin: .zero, size: .init(width: 842, height: 1191))
        case .usLetter: return CGRect(origin: .zero, size: .init(width: 612, height: 792))
        case .usLegal: return CGRect(origin: .zero, size: .init(width: 612, height: 1008))
        case .usTabloid: return CGRect(origin: .zero, size: .init(width: 792, height: 1224))
        case .usExecutive: return CGRect(origin: .zero, size: .init(width: 522, height: 756))
        }
    }
    
    static func regionDefaultPaper(for locale: Locale = .current) -> PaperSize {
        let currentRegion = Locale.current.region?.identifier
        if let region = currentRegion {
            if region.contains("US") || region.contains("CA") { return .usLetter }
        }
        return .a4
    }
    
    static func getBox(name: String) -> CGRect {
        let paperSize = PaperSize.from(displayName: name)
        return box(for: paperSize ?? regionDefaultPaper())
    }
}

struct PDFConfiguration {
    var mediaBox: CGRect
    let margins: EdgeInsets
    let columns: Int
    let scale: CGFloat
        
    init(mediaBox: String, margins: EdgeInsets, columns: Int, scale: CGFloat) {
        self.margins = margins
        self.columns = columns
        self.scale = scale
        self.mediaBox = MediaBoxes.getBox(name: mediaBox)
    }
    
    var contentRect: CGRect {
        CGRect(
            x: mediaBox.minX + margins.leading,
            y: mediaBox.minY + margins.bottom,
            width: mediaBox.width - margins.leading - margins.trailing,
            height: mediaBox.height - margins.top - margins.bottom
        )
    }
}

class PDFLayoutState {
    var page = 1
    var column = 1

    var xPos: CGFloat = 0
    var yPos: CGFloat = 0
    var columnTop: CGFloat = 0
}

final class PDFLayoutEngine {
    var config: PDFConfiguration
    var state = PDFLayoutState()
    
    var columnSize: CGFloat { config.contentRect.width / CGFloat(config.columns) }
    var columnOffsetx: CGFloat { CGFloat(state.column - 1) * columnSize }
    
    init(config: PDFConfiguration) {
        self.config = config
    }

    func appendContent(for height: CGFloat) -> Bool {
        let exceedsColumn = state.yPos + height > config.contentRect.height
        return exceedsColumn ? advanceColumn() : false
    }

    func advanceColumn() -> Bool {
        let needsNewPage = tryAdvanceColumn()
        
        if needsNewPage {
            advancePage()
            return true
        }
        
        return false
    }
    
    private func tryAdvanceColumn() -> Bool {
        state.column += 1
        
        if state.column > config.columns {
            return true // neue Seite
        }
        
        state.yPos = state.column > 1 ? state.columnTop : 0.0
        return false
    }

    func advancePage() {
        state.yPos = 0
        state.xPos = 0
        state.page += 1
        state.column = 1
        state.columnTop = 0
    }
    
    func place(height: CGFloat) -> CGPoint {
        let x = columnOffsetx + config.contentRect.minX
        let y = state.yPos + config.contentRect.minY

        let point = CGPoint(x: x, y: y)
        state.xPos = x
        state.yPos += height
        return point
    }
}

final class PDFRenderer {
    func measure<V: View>(_ view: V) -> CGSize {
        let renderer = ImageRenderer(content: view)
        var size = CGSize.zero
        renderer.render { s, _ in size = s }
        return size
    }

    func draw<V: View>(_ view: V, in context: CGContext) {
        let renderer = ImageRenderer(content: view)
        renderer.render { _, render in
            render(context)
        }
    }
}

final class PDFGenerator {
    private let context: CGContext
    private let layout: PDFLayoutEngine
    private let renderer = PDFRenderer()
    private var metadata: [CFString: String] = [:]
    private var userSettings: UserSettings

    private(set) var url: URL
    
    init(config: PDFConfiguration, userSettings: UserSettings) throws {
        self.layout = PDFLayoutEngine(config: config)
        self.userSettings = userSettings
        
        let tmpDirectoryURL = FileManager.default.temporaryDirectory
        url = tmpDirectoryURL
            .appendingPathComponent("output")
            .appendingPathExtension(for: .pdf)

        guard let ctxt = CGContext(url as CFURL, mediaBox: &layout.config.mediaBox, metadata as CFDictionary) else {
            throw NSError(domain: "Failed to create PDF context", code: 1)
        }
        self.context = ctxt
    }

    func startPDF() {
        PDFLog.debug("start")
        context.beginPDFPage(nil)
    }

    func endPDF() {
        PDFLog.debug("end")
        context.endPDFPage()
        context.closePDF()
    }

    func draw<V: View>(_ view: V) {
        let size = renderer.measure(view.environment(userSettings))

        // linespacing für unterste Zeile der Spalte ignorieren
        if layout.appendContent(for: (size.height - userSettings.linespacingpdf) * layout.config.scale) {
            PDFgenNewPage()
        }
                    
        let pos = layout.place(height: size.height * layout.config.scale)

        context.saveGState()
        
//        PDFLog.debug("x \(pos.x) y \(pos.y) height \(size.height) col \(layout.state.column) page \(layout.state.page)")
        context.clip(to: layout.config.contentRect)
        context.scaleBy(x: layout.config.scale, y: layout.config.scale)
        
        let pdfY = layout.config.mediaBox.height - pos.y - (size.height * layout.config.scale)
        context.translateBy(x: pos.x / layout.config.scale, y: pdfY / layout.config.scale)
        
        renderer.draw(view.environment(userSettings), in: context)

        context.restoreGState()
    }
    
    private func PDFgenNewPage() {
        PDFLog.debug("end")
        context.endPDFPage()
        PDFLog.debug("begin")
        context.beginPDFPage(nil)
    }

    func markColumnTop() {
        PDFLog.debug("markColumnTop")
        layout.state.columnTop = layout.state.yPos
    }
    
    func forceNewPage() {
        PDFLog.debug("forceNewPage")

        PDFgenNewPage()
        layout.advancePage()
    }
    
    func forceColumnBreak() {
        PDFLog.debug("forceColumnBreak")
        if layout.advanceColumn() {
            PDFgenNewPage()
        }
    }
}


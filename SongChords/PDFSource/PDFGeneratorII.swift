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

struct PDFConfiguration {
    let mediaBox: CGRect
    let margins: EdgeInsets
    let columns: Int
    let scale: CGFloat

    var contentRect: CGRect {
        CGRect(
            x: mediaBox.minX + margins.leading,
            y: mediaBox.minY + margins.bottom,
            width: mediaBox.width - margins.leading - margins.trailing,
            height: mediaBox.height - margins.top - margins.bottom
        )
    }
}

struct PDFLayoutState {
    var page = 0
    var column = 0

    var xPos: CGFloat = 0
    var yPos: CGFloat = 0
    var columnTop: CGFloat = 0
}

final class PDFLayoutEngine {
    let config: PDFConfiguration
    var state = PDFLayoutState()

    init(config: PDFConfiguration) {
        self.config = config
    }

    func requiresNewPage(for height: CGFloat) -> Bool {
        state.yPos + height > config.contentRect.height
    }

    func advanceColumn() -> Bool {
        state.column += 1
        if state.column >= config.columns {
            state.column = 0
            return true // neue Seite
        }
        return false
    }

    func place(height: CGFloat) -> CGPoint {
        let point = CGPoint(x: state.xPos, y: state.yPos)
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

final class PDFGeneratorII {
    private let context: CGContext
    private let layout: PDFLayoutEngine
    private let renderer = PDFRenderer()

    init(context: CGContext, config: PDFConfiguration) {
        self.context = context
        self.layout = PDFLayoutEngine(config: config)
    }

    func draw<V: View>(_ view: V) {
        let size = renderer.measure(view)

        if layout.requiresNewPage(for: size.height) {
            context.endPDFPage()
            context.beginPDFPage(nil)
            layout.state = PDFLayoutState()
        }

        let pos = layout.place(height: size.height)

        context.saveGState()
        context.translateBy(x: pos.x, y: pos.y)
        renderer.draw(view, in: context)
        context.restoreGState()
    }
}

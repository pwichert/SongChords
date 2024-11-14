//
//  PDFViewer.swift
//  SongChords
//
//  Created by Peter Wichert on 16.01.24.
//

import SwiftUI
import PDFKit

#if os(macOS)
typealias UIViewRepresentable = NSViewRepresentable
typealias UIViewRepresentableContext = NSViewRepresentableContext
#endif

struct PDFKitView: UIViewRepresentable {
    typealias NSViewType = PDFView
    typealias UIViewType = PDFView

    let url: URL
    private let delegate = PDFKitViewDelegate()
    
    func makeUIView(context: UIViewRepresentableContext<PDFKitView>) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: self.url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.delegate = delegate
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: UIViewRepresentableContext<PDFKitView>) {
    }
    
    // für macOS
    func makeNSView(context: Context) -> PDFView {
        makeUIView(context: context)
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        updateUIView(nsView, context: context)
    }
}

class PDFKitViewDelegate: NSObject, PDFViewDelegate {
    func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
        print("pdfViewWillClick")
        // kein Link möglich wegen AppStore-Richtlinie
    }
}

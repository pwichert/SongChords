//
//  PDFGenerator.swift
//  SongChords
//
//  Created by Peter Wichert on 04.01.24.
//

import SwiftUI

//extension String: Error {}

nonisolated
class MediaBoxes {
    // 72 dpi
    
    static let mediaBoxes: [String:CGRect] = [
        "A5" : CGRect(origin: .zero, size: .init(width: 420, height: 595)),
        "A4" : CGRect(origin: .zero, size: .init(width: 595, height: 842)),
        "A3" : CGRect(origin: .zero, size: .init(width: 842, height: 1191)),
        "US Letter" : CGRect(origin: .zero, size: .init(width: 612, height: 792)),
        "US Legal" : CGRect(origin: .zero, size: .init(width: 612, height: 1008)),
        "US Tabloid" : CGRect(origin: .zero, size: .init(width: 792, height: 1224)),
        "US Executive" : CGRect(origin: .zero, size: .init(width: 522, height: 756))
    ]
    
    static func getBox(name: String) -> CGRect {
        var defaultBox: String = "A4"
        
        let currentRegion = Locale.current.region?.identifier
        if let region = currentRegion {
            if region.contains("US") || region.contains("CA") { defaultBox = "US Letter" }
        } else {
            print("Konnte die aktuelle Region nicht bestimmen.")
        }
        
        for (key,value) in MediaBoxes.mediaBoxes {
            if key == name { return value }
        }
        
        return MediaBoxes.mediaBoxes[defaultBox]!
    }
}

enum PDFGeneratorError: Error {
    case invalidMediaBox
    case invalidPageSize
    case invalidPageOrientation
    case invalidPageLayout
    case invalidPageMargins
    case invalidPageContent
    case invalidPageContentSize
    case invalidPageContentPosition
    case invalidPageContentScale
    case securityScopedResource
}

nonisolated
class PDFGenerator {
    private var userSettings: UserSettings
    private var cols: Int = 1
    private var mediaBox: CGRect

    private var context: CGContext
    private var testContext: CGContext
    private(set)var url: URL
    private var testUrl: URL
    private var clipBox: CGRect
    private var metadata: [CFString: String] = [:]
    
    private var xPos: CGFloat = 0.0
    private var yPos: CGFloat = 0.0
    
    private var page: Int = 0
    private var currentCol = 0
    private var lastCol = 0
    private var columnTop: CGFloat = 0
    
    private var xTranslate: CGFloat = 0
    private var yTranslate: CGFloat = 0

    private var scale: CGFloat = 1
    private var reScale: CGFloat = 1
    
    init(userSettings: UserSettings, mediaBox: CGRect, cols: Int, viewURL: Bool = false) throws {
        self.userSettings = userSettings
        self.cols = cols

        let cacheDirectoryURL = FileManager.default.temporaryDirectory //.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: .cachesDirectory, create: true)
        
        url = cacheDirectoryURL
            .appendingPathComponent(viewURL ? "outputv" : "output")
            .appendingPathExtension(for: .pdf)
        
        testUrl = cacheDirectoryURL
            .appendingPathComponent(viewURL ? "outputvTest" : "outputTest")
            .appendingPathExtension(for: .pdf)

        print(url.absoluteString)
        print(testUrl.absoluteString)

//        let urlSec = url.startAccessingSecurityScopedResource()
//        let testUrlSec = testUrl.startAccessingSecurityScopedResource()
//        
//        if !urlSec || !testUrlSec {
//            throw PDFGeneratorError.securityScopedResource
//        }
        
        scale = userSettings.printingscale / 100
        reScale = 1 / scale
        
        self.mediaBox = mediaBox
        print("mediabox: \(cols) \(self.mediaBox)")
        
        // In testContext wird parallel gerendert, umd die Größe vorher bestimmen zu können
        testContext = CGContext(testUrl as CFURL, mediaBox: &self.mediaBox, metadata as CFDictionary)!
        context = CGContext(url as CFURL, mediaBox: &self.mediaBox, metadata as CFDictionary)!
        
        clipBox = CGRect(x: self.mediaBox.minX + userSettings.marginleft, y: self.mediaBox.minY + userSettings.marginbottom, width: self.mediaBox.width - (userSettings.marginleft + userSettings.marginright), height: self.mediaBox.height - (userSettings.margintop + userSettings.marginbottom))
    }
    
    func startPDF() {
        page = 0
        nextPage()
        
        testContext.beginPDFPage(nil)
    }
    
    func endPDF() throws {
        print("endPDFPage")
       
        context.endPDFPage()
        context.closePDF()

        testContext.endPDFPage()
        testContext.closePDF()
        
//        url.stopAccessingSecurityScopedResource()
//        testUrl.stopAccessingSecurityScopedResource()
        
        try FileManager.default.removeItem(at: testUrl)
    }
    
    func setColumnTop() {
        // Überschrift reduziert Spaltenhöhe auf dieser Seite
        columnTop = yPos * scale
//        print("columnTop \(columnTop)")
    }
    
    func setNewPage() {
        // Directive { new_page }
        context.endPage()
        print("endPDFPage setNewPage")
        nextPage()
    }
    
    
    @MainActor
    func drawTest<T:View>(col: Int, view: T) {
        context.beginPDFPage(nil)
        let scale = 0.7
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: (mediaBox.height-30) * 1/scale)
        
        let renderer = ImageRenderer(content: view.environment(userSettings))
        renderer.render { size, renderer in
            renderer(context)
        }
        
        context.endPDFPage()
        context.closePDF()
    }
    
    @MainActor
    func draw<T:View>(col: Int, view: T) {
        var viewSize = CGSizeZero
        let renderer = ImageRenderer(content: view.environment(userSettings))
        
        // Rendern, um die Größe VOR dem eigentlichen Rendern zu wissen
        renderer.render { size, renderer in
            renderer(testContext)
            viewSize = size
        }

        // View passt gar nicht auf Seite
        if viewSize.height > (mediaBox.height - mediaBox.minY - userSettings.marginbottom - userSettings.margintop) * reScale {
            return
        }
        
        // col hat gewechselt
        var toNextCol: Bool = lastCol != col
        lastCol = col
        
        // View überschreitet Seitenende
//        print("xpos \(Int(xPos)) ypos \(Int(yPos)) Seitenende ? ypos \(Int(yPos)) + \(Int(viewSize.height)) > \(mediaBox.height) - \(vm.marginbottom * reScale)")
        if yPos + viewSize.height > (mediaBox.height - mediaBox.minY - userSettings.marginbottom) * reScale {
            toNextCol = true
        }

        // cols == 1 , wenn cols nicht gesetzt wurde. Dann ist jeder {colb} eine neue Seite, col wurde einfach hochgezählt
        // (currentCol + 1) % cols == 0 , wenn letzte column erreicht. Dann neue Seite
        let toNextPage: Bool = toNextCol && (cols == 1 || (currentCol + 1) % cols == 0)

        if toNextPage {
            // neue Seite
            context.endPage()
            print("endPDFPage inside")
            nextPage()
        } else if toNextCol {
            // neue Spalte
            currentCol = (currentCol + 1) % cols
            
            let xSpace = (mediaBox.width - userSettings.marginleft - userSettings.marginright) / CGFloat(cols)
            xPos += xSpace
            toOrigin()
            yPos = columnTop * reScale
            translate(x: xPos, y: mediaBox.height - columnTop)
        }
        
        translate(x: 0, y: -viewSize.height * scale)
        yPos += viewSize.height
        
        renderer.render { size, renderer in
            renderer(context)
        }
    }
    
    private func nextPage() {
        page += 1
        print("beginPDFPage \(page)")
        context.beginPDFPage(nil)
        context.clip(to: clipBox)
        context.scaleBy(x: scale, y: scale)

        xTranslate = 0
        yTranslate = 0
        translate(x: mediaBox.minX + userSettings.marginleft, y: mediaBox.height - userSettings.margintop)
        
        xPos = mediaBox.minX + userSettings.marginleft
        yPos = userSettings.margintop * reScale
        columnTop = userSettings.margintop
        currentCol = 0
    }
    
    private func translate(x: CGFloat, y: CGFloat) {
        context.translateBy(x: x * reScale, y: y * reScale)
        xTranslate += x * reScale
        yTranslate += y * reScale
//        print("x \(Int(x)) y \(Int(y)) translate zu \(Int(xTranslate)) \(Int(yTranslate))")
    }
    
    private func toOrigin() {
        context.translateBy(x: -xTranslate, y: -yTranslate)
//        print("x \(Int(-xTranslate)) y \(Int(-yTranslate)) toOrigin")

        xTranslate = 0
        yTranslate = 0
    }
    
    func deg2rad(_ number: Double) -> Double {
        return number * .pi / 180
    }
}

private struct testView: View {
    var body: some View {
        Text(Date.now.description)
    }
}

private struct SimpleView: View {
    var body: some View {
        ContainerView {
            Text("")
        }
    }
}

private struct GreedyContainerView<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ContainerView<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
    }
}

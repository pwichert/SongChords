//
//  ChordDiagramView.swift
//  SongChords
//
//  Created by Peter Wichert on 17.02.25.
//


import SwiftUI

struct ChordDiagramView: View {
    let chord: TextElement
    let frets: [ChordFretVariant]
    
    init(chord: TextElement) {
        self.chord = chord
        frets = chord.chord?.getFrets() ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(chord.txt)
                .font(.title)
                .bold()
                .padding()
            
            if frets.count > 0 {
                TabView {
                    ForEach(frets, id: \.self) { variant in
                        ChordFretboardView(variant: variant)
                            .frame(width: 185, height: 200)
                    }
                }
            } else {
                Text("Sorry, no diagram available at the moment.")
                    .multilineTextAlignment(.center)
                    .font(.body).bold().padding()
            }
        }.lineLimit(nil)
        .frame(width: 200, height: 300)
        #if os(iOS)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .onAppear {
            // Farbe der Punkte anpassen
            let activeColor = UIColor { $0.userInterfaceStyle == .dark ? .lightGray : .darkGray }
            let inactiveColor = UIColor { $0.userInterfaceStyle == .dark ? .darkGray : .lightGray }
        
            UIPageControl.appearance().currentPageIndicatorTintColor = activeColor
            UIPageControl.appearance().pageIndicatorTintColor = inactiveColor
        }
        #endif
    }
}
    
struct ChordFretboardView: View {
    let variant: ChordFretVariant
    
    private let stringSpacing: CGFloat = 25
    private let fretSpacing: CGFloat = 30
    private let fretCount: Int = 5
    
    private let baseSpacingLeft: CGFloat = 12   // baseFret-Zahl-Start
    private let spacingLeft: CGFloat = 19 + 12   // + baseSpacingLeft: Platz für baseFret-Zahl
    private let spacingTop: CGFloat = 15    // Platz für x o
    
    var body: some View {
        ZStack {
            // Bünde
            ForEach(0...fretCount, id: \.self) { fret in
                Path { path in
                    let y = CGFloat(fret) * fretSpacing + spacingTop
                    path.move(to: CGPoint(x: spacingLeft, y: y))
                    path.addLine(to: CGPoint(x: stringSpacing * 5 + spacingLeft, y: y))
                }
                .stroke(Color.primary.opacity(1), style: StrokeStyle(lineWidth: fret == 0 ? 6 : 2, lineCap: .round, lineJoin: .round))
            }

            // Gitarrensaiten
            ForEach(0..<6, id: \.self) { string in
                Path { path in
                    let x = CGFloat(string) * stringSpacing + spacingLeft
                    path.move(to: CGPoint(x: x, y: spacingTop))
                    path.addLine(to: CGPoint(x: x, y: fretSpacing * CGFloat(fretCount) + spacingTop))
                }
                .stroke(Color.primary.opacity(1), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            
            // Notenpunkte setzen
            ForEach(0..<6, id: \.self) { string in
                let fret = variant.frets.count > string ? variant.frets[string] : 0
                let finger = variant.fingers.count > string ? variant.fingers[string] : nil
                if fret > 0 {
                    Circle()
                        .fill(Color.primary.opacity(1))
                        .overlay {
                            if let finger {
                                Text(String(finger))
                                    .font(.system(size: 12, weight: .bold, design: .default))
                                    .foregroundStyle(Color.gray)
                            } else { EmptyView() }
                        }
                        .frame(width: 17, height: 17)
                        .position(x: CGFloat(string) * stringSpacing + spacingLeft,
                                  y: CGFloat(fret-variant.base) * fretSpacing + fretSpacing / 2 + spacingTop)
                }
            }
            
            // Barre-Akkord zeichnen
            if case let (start, end) = barrePositions {
                if let start, let end, start < end {
                    Path { path in
                        let barreFret = variant.frets.sorted().first(where: { $0 > 0 }) ?? 1
                        let y = CGFloat(barreFret - variant.base) * fretSpacing + fretSpacing / 2 + spacingTop
                        path.move(to: CGPoint(x: start - 1, y: y))
                        path.addLine(to: CGPoint(x: end + 1, y: y))
                    }
                    .stroke(Color.primary.opacity(1), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                }
            }
            
            // x/o Anzeige
            ForEach(0..<6, id: \.self) { string in
                if variant.frets[string] < 0 {
                    Text("x").font(.system(size: 18, weight: .bold, design: .default))
                        .position(x: CGFloat(string) * stringSpacing + spacingLeft, y: 0)
                } else if variant.frets[string] == 0 {
                    Text("o").font(.system(size: 18, weight: .bold, design: .default))
                        .position(x: CGFloat(string) * stringSpacing + spacingLeft, y: 0)
                }
            }
            
            // Basis-Fretnummer
            if variant.base > 1 {
                Text(String(format: "%2i", variant.base)).position(x: baseSpacingLeft, y: fretSpacing / 2 + spacingTop).font(.system(size: 14, weight: .bold, design: .default))
            }
        }
    }
    
    private var barrePositions: (start: CGFloat?, end: CGFloat?) {
        var start: CGFloat? = nil
        var end: CGFloat? = nil
        
        for string in 0..<6 {
            let fret = variant.frets[string]
            let finger = variant.fingers[string]
            
            if fret > 0, finger == 1 {
                let position = CGFloat(string) * stringSpacing + spacingLeft
                if start == nil {
                    start = position
                }
                end = position
            }
        }
        return (start, end)
    }
}

//
//  ChordDiagramView.swift
//  SongChords
//
//  Created by Peter Wichert on 17.02.25.
//


import SwiftUI

struct ChordDiagramView: View {
    let chord: ChordShape
    
    var body: some View {
        TabView {
                ForEach(chord.variants.indices, id: \.self) { index in
                    VStack(spacing: 10) {
                        Text(chord.name)
                            .font(.title)
                            .bold()
                        
                        ChordFretboardView(variant: chord.variants[index])
                            .frame(width: 180, height: 200)
                    }
                }
        }
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
    let variant: ChordVariant
    let stringSpacing: CGFloat = 25
    let fretSpacing: CGFloat = 30
    let fretCount: Int = 5
    
    let spacingLeft: CGFloat = 19   // Platz für baseFret-Zahl
    let spacingTop: CGFloat = 15    // Platz für x o
    
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
                Text(String(format: "%2i", variant.base)).position(x: 0, y: fretSpacing / 2 + spacingTop).font(.system(size: 14, weight: .bold, design: .default))
            }
        }
        .padding()
    }
}

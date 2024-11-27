//
//  Grundton.swift
//  SongChords Develop
//
//  Created by Peter Wichert on 03.11.24.
//

import Foundation

// Akkordstruktur
public struct ParsedChord: Identifiable {
    public let id = UUID()
    let grundton: Grundton
    let istMoll: Bool
    let hatKreuz: Bool
    let hatB: Bool
    let mehrklang: Mehrklang?
    let basston: Grundton?  // Slash-Akkorde
    let bassKreuz: Bool
    let bassB: Bool
    let minMoll: Bool        // min als Moll-Schreibweise

    public func toString(transpose: Int, convertGerman: Bool) -> String {
        if transpose != 0 {
            let tChord = transposeChord(self, by: transpose)!
            return tChord.toString(transpose: 0, convertGerman: convertGerman)
        }

        var result: String = grundton.rawValue.uppercased()
        
        if hatKreuz { result.append(Versetzungszeichen.hash.rawValue) }
        if hatB { result.append(Versetzungszeichen.b.rawValue) }
        if istMoll { result.append(minMoll ? "min" : "m") }

        if convertGerman { result = toGermanString(txt: result) }
        
        if let mehrklang { result.append(mehrklang.rawValue) }
        if let basston {
            var bassResult = basston.rawValue.uppercased()
            if bassKreuz { bassResult.append(Versetzungszeichen.hash.rawValue) }
            if bassB { bassResult.append(Versetzungszeichen.b.rawValue) }
            
            if convertGerman { bassResult = toGermanString(txt: bassResult) }
            result += "/\(bassResult)"
        }
        
        return result
    }
    
    private func toGermanString(txt: String) -> String {
        if txt.starts(with: "Bb") { return "B" + txt[txt.index(txt.startIndex, offsetBy: 2)...] }
        if txt.starts(with: "A#") { return "B" + txt[txt.index(txt.startIndex, offsetBy: 2)...] }
        if txt.starts(with: "B") { return "H" + txt[txt.index(after: txt.startIndex)...] }
        return txt
    }
    
    private func transposeChord(_ chord: ParsedChord, by halfSteps: Int) -> ParsedChord? {
        let tones = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let flats = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
                
        // Helper-Funktion für neuen Ton basierend auf Transpositionsrichtung
        func transposedTone(originalTone: Grundton, isSharp: Bool, isFlat: Bool, halfSteps: Int) -> (Grundton, Bool, Bool)? {
            let trx = halfSteps >= 0 ? tones : flats
            let transposeVal = if halfSteps >= 0 {
                halfSteps % trx.count
            } else {
                -((-halfSteps) % trx.count)
            }
            
            var gtvz = originalTone.rawValue.uppercased() + (isSharp ? "#" : (isFlat ? "b" : ""))
            if gtvz == "Cb" { gtvz = "B"}
            
            let tonesIndex = tones.firstIndex(of: gtvz)
            var idx = tonesIndex ?? flats.firstIndex(of: gtvz)
            
            idx = (idx! + transposeVal + trx.count) % (trx.count)
            let newToneString = trx[idx!]
            
            let newIsSharp = newToneString.contains("#")
            let newIsFlat = newToneString.contains("b")
            
            // Konvertiere zum Grundton-Enum-Wert
            if let newTone = Grundton(rawValue: String(newToneString.lowercased().first!)) {
                return (newTone, newIsSharp, newIsFlat)
            }
            
            return nil
        }
        
        // Transponierter Grundton
        guard let (newGrundton, newHatKreuz, newHatB) = transposedTone(originalTone: chord.grundton, isSharp: chord.hatKreuz, isFlat: chord.hatB, halfSteps: halfSteps) else {
            return nil
        }
        
        // Transponierter Basston, falls vorhanden
        var newBasston: Grundton? = nil
        var newBassKreuz = false
        var newBassB = false
        if let basston = chord.basston {
            if let (transposedBasston, bassKreuz, bassB) = transposedTone(originalTone: basston, isSharp: chord.bassKreuz, isFlat: chord.bassB, halfSteps: halfSteps) {
                newBasston = transposedBasston
                newBassKreuz = bassKreuz
                newBassB = bassB
            }
        }
        
        // Neues `ParsedChord`-Objekt mit transponierten Werten erstellen
        return ParsedChord(
            grundton: newGrundton,
            istMoll: chord.istMoll,
            hatKreuz: newHatKreuz,
            hatB: newHatB,
            mehrklang: chord.mehrklang,
            basston: newBasston,
            bassKreuz: newBassKreuz,
            bassB: newBassB,
            minMoll: chord.minMoll
        )
    }
}

public enum Grundton: String, CaseIterable, Codable {
    case c,d,e,f,g,a,b
}

public enum Versetzungszeichen: String, CaseIterable, Codable {
    case hash = "#"
    case b
}

public enum Mehrklang: String, CaseIterable, Codable {
    case verm = "dim"
    case ueberm = "aug"
    case sexte = "6"
    case sexteNone = "6/9"
    case sept = "7"
    case grSept = "maj7"
    case septNone = "9"
    case septGrSeptNone = "maj9"
    case noneUndezime = "11"
    case noneTredezime = "13"
    case none = "add9"
    case uebermQuinte = "7#5"
    case vermQuinte = "7b5"
    case alteriert = "7b5#9"
    case dim = "dim7"

    case sus = "sus"
    case sus2 = "sus2"
    case sus4 = "sus4"
    
    case powerchord = "5"
}

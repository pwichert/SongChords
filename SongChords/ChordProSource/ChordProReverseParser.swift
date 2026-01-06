//
//  ChordProReverseParser.swift
//  SongChords
//
//  Created by Peter Wichert on 13.11.24.
//

public class ChordProReverseParser {
    private(set) var chunks: [SongRenderChunk] = []
    
    public init() {}
    
    public func toString() -> String {
        var res: String = ""

        for chunk in chunks {
            switch chunk.content {
                
            case .sectionStarted(let section):
                res.append("[" + section + "]\n")
                
            case .splittedline(chords: let chords, texts: let texts, plaintext: let plaintext):
                var split = SplittedLine(chords: chords, texts: texts, plainText: plaintext)
                res.append(mixSplittedLine(splittedLine: &split) + "\n")
                
            default:
                break
            }
        }
        
        return res
    }
        
    public func parse(input: String, rootSystem: inout ChordRoot) {
        var lines = [String]()
        input.enumerateLines{ (line, _) -> () in
            let cleanLine = line.replacingOccurrences(of: "\r", with: "")
            lines.append(cleanLine)
        }
        
        var lastLine: (textElement: [TextElement], isChord: Bool)?

        var sectionName: String = ""
        var cnt = lines.count
        
        // SplittedLines erzeugen
        
        for line in lines {
            cnt -= 1
            
            let curLine = isChordline(line: line, rootSystem: &rootSystem)
            
            if line.starts(with: "[") && line.last == "]" {
                let s = line.index(after: line.startIndex)
                let e = line.index(before: line.endIndex)
                
                sectionName = String(line[s..<e])
                chunks.append(SongRenderChunk(id: 0,content: .sectionStarted(sectionName)))
                continue
            }
            
            if curLine.isChord {
                // aktuelle Zeile sind Chords
                if let last = lastLine, last.isChord {
                    // letzte Zeile waren auch Chords, also eine einzelne Chordzeile ohne Text
                    chunks.append(SongRenderChunk(id: 0, content: .splittedline(chords: last.textElement, texts: [], plaintext: "")))
                }
                // für nächste Zeile merken
                lastLine = curLine
                if cnt == 0 { chunks.append(SongRenderChunk(id: 0, content: .splittedline(chords: curLine.textElement, texts: [], plaintext: ""))) }
            } else {
                // aktuelle Zeile keine Chords
                if let last = lastLine, last.isChord {
                    // letzte Zeile waren Chords, also komplette Chord/Text-Zeile
                    chunks.append(SongRenderChunk(id: 0, content: .splittedline(chords: last.textElement, texts: curLine.textElement, plaintext: "")))

                    // Text als erledigt merken
                    lastLine = nil
                } else  {
                    // letzte Zeile waren keine Chords, also eine einzelne Textzeile ohne Chord
                    chunks.append(SongRenderChunk(id: 0, content: .splittedline(chords: [], texts: curLine.textElement, plaintext: "")))

                    // Text als erledigt merken
                    lastLine = nil
                }
            }
        }
    }
    
    private func isChordline(line: String, rootSystem: inout ChordRoot) -> (textElement: [TextElement], isChord: Bool) {
        let spl = splitWords(line: line)
        
        var chords: [TextElement] = []
        var txts: [TextElement] = []
        var numChords: Int = 0
        var numTexts: Int = 0
        
        for word in spl {
            // falls es Chords sind
            if let chord = ParsedChord.parse(word.txt, rootSystem: &rootSystem, strict: true) {
                chords.append(TextElement(txt: "[" + chord.name + "]", isChordcomment: false, fontOffset: Double(word.pos), background: false, chord: chord))
                numChords += 1
            } else {
                chords.append(TextElement(txt: word.txt, isChordcomment: false, fontOffset: Double(word.pos), background: false, chord: nil))
                numTexts += 1
            }
            
            // falls es keine Chords sind
            txts.append(TextElement(txt: word.txt, isChordcomment: false, fontOffset: Double(word.pos), background: false, chord: nil))
        }
        
        if numChords > 0 && numChords > spl.count / 2 { return (chords, true) }
        return (txts, false)
    }
    
    private func splitWords(line: String) -> [(pos: Int, txt: String)] {
        var res = [(Int, String)]()
        let ar = line.split(separator: " ", omittingEmptySubsequences: false)
        
        var emptyCnt = 0
        var pos = 0

        for i in ar {
            if i.isEmpty {
                emptyCnt += 1
            }
            else {
                pos += emptyCnt
                if res.count > 0 {
                    // emptyCnt und split(): Blanks VOR dem ersten Wort werden ALLE gezählt. Nach dem ersten Wort fehlt immer eines.
                    pos += 1
                }
                
                res.append((pos, String(i)))
                pos += i.count
                emptyCnt = 0
            }
        }
        
        return res
    }
    
    private func mixSplittedLine(splittedLine: inout SplittedLine) -> String {
        var txt = splittedLine.textsToString() ?? ""
        
        // absteigend sortiert
        for chord in splittedLine.chords.sorted(by: { $0.fontOffset > $1.fontOffset }) {
            if Int(chord.fontOffset) > txt.count { txt.append(String(repeating: " ", count: Int(chord.fontOffset) - txt.count)) }
            
            // Chords haben schon [], Texte werden ansonsten hier zum ChordComment mit [* ...]
            let t = (chord.txt.first == "[" && chord.txt.last == "]" ? chord.txt : "[*" + chord.txt + "]")
            txt.insert(contentsOf: t, at: txt.index(txt.startIndex, offsetBy: Int(chord.fontOffset)))
        }
        
        return txt
    }
}

//
//  ChordProReverseParser.swift
//  SongChords
//
//  Created by Peter Wichert on 13.11.24.
//

// MARK: - New, more robust reverse parser
public final class ChordProReverseParser {
    private let rootSys: RootSys
    private var outputLines: [String] = []

    public init(rootSys: RootSys) {
        self.rootSys = rootSys
    }

    // Parse an input consisting of chord/text pairs separated by newlines.
    // Rules:
    // - Lines are processed top-to-bottom.
    // - A chord line is a line where the majority of tokens look like chords.
    // - If a chord line is followed by a non-chord line, they form a pair (chords over text).
    // - Chord-only lines (no following text) are emitted as a single line with inline chords at offsets.
    // - Text-only lines are passed through.
    // - Empty lines are preserved.
    public func parse(input: String) {
        outputLines.removeAll(keepingCapacity: true)

        // Split lines while preserving empty lines
        var lines: [String] = []
        input.enumerateLines { line, _ in
            lines.append(line.replacingOccurrences(of: "\r", with: ""))
        }
        if input.hasSuffix("\n") && (lines.isEmpty || lines.last != "") {
            // enumerateLines doesn't add a trailing empty line if input ends with \n
            // add empty line explicitly
            lines.append("")
        }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                outputLines.append("")
                i += 1
                continue
            }
            
            // Section: [Vers]
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                outputLines.append(line)
                i += 1
                continue
            }
            
            let chordInfo = analyze(line: line)
            if chordInfo.isChordLine {
                // Try to pair with next line if it's not a chord line and not empty
                if i + 1 < lines.count {
                    let next = lines[i + 1]
                    let nextInfo = analyze(line: next)
                    if !nextInfo.isChordLine && !nextInfo.tokens.isEmpty {
                        // Chords over text: merge into one ChordPro line
//                        let merged = mergeChordOverText(chords: chordInfo.tokens, text: next)
                        let merged = mergeChord(tokens: chordInfo.tokens, text: next.trimmingCharacters(in: .whitespaces))
//                        print("chord+text \(line) + \(next)")
                        outputLines.append(merged)
                        i += 2
                        continue
                    }
                }
                // Chord-only line
//                let merged = mergeChordOnly(tokens: chordInfo.tokens)
                let merged = mergeChord(tokens: chordInfo.tokens, text: "")
//                print("chordonly \(merged)")
                outputLines.append(merged)
                i += 1
                continue
            } else {
                // Text-only line
//                print("textonly \(line)")
                outputLines.append(line)
                i += 1
                continue
            }
        }
    }

    public func toString() -> String {
        return outputLines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private struct Token {
        let offset: Int
        let raw: String
        let chord: Chord?
    }

    private func analyze(line: String) -> (isChordLine: Bool, tokens: [Token]) {
        let parts = splitWithOffsets(line: line)
        var tokens: [Token] = []
        var chordCount = 0
        for (off, raw) in parts {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if let chord = try? Chord.parse(trimmed, preferedGermanParsing: rootSys == .german, strict: true) {
                tokens.append(Token(offset: off, raw: trimmed, chord: chord))
                chordCount += 1
            } else if trimmed == "|" {
                tokens.append(Token(offset: off, raw: trimmed, chord: nil))
                chordCount += 1
            } else {
                tokens.append(Token(offset: off, raw: trimmed, chord: nil))
            }
        }

        // Heuristic: chord line if more than half tokens are chordish
        let isChord = chordCount > 0 && chordCount * 2 >= max(1, tokens.count)
        return (isChord, tokens)
    }

    private func mergeChord(tokens: [Token], text: String) -> String {
        let tokensInText = tokens.filter({ $0.offset < text.count })
        let tokensWithoutText = tokens.filter({ $0.offset >= text.count })
        
        let res1 = mergeChordOverText(chords: tokensInText, text: text)
        let res2 = mergeChordOnly(tokens: tokensWithoutText)
        return res1 + res2.dropFirst(text.count)
    }
    
    private func mergeChordOverText(chords: [Token], text: String) -> String {
        // Build a mutable buffer from the text
        var buffer = text
        
        // Insert from right to left to keep offsets stable relative to the original text
        for t in chords.sorted(by: { $0.offset > $1.offset }) {
            let insertion = bracketed(t)
            let off = max(0, t.offset)
            if off > buffer.count {
                buffer.append(String(repeating: " ", count: off - buffer.count))
            }
            
            let idx = buffer.index(buffer.startIndex, offsetBy: off)
            buffer.insert(contentsOf: insertion, at: idx)
        }
        
        return buffer
    }

    private func mergeChordOnly(tokens: [Token]) -> String {
        // Build left-to-right to preserve exact spacing between tokens
        let ordered = tokens.sorted(by: { $0.offset < $1.offset })
        var buffer = ""
        var lst: Token?     // Vorgänger
        
        for t in ordered {
            var dist = t.offset
            if let lst {
                // Anzahl der Leerzeichen zwischen den Chords bestimmen (dist)
                let diff = t.offset - lst.offset
                dist = max(0, diff - lst.raw.count)
            }
            
            buffer.append(String(repeating: " ", count: dist))
            buffer.append(bracketed(t))
                        
            lst = t
        }
        
        return buffer
    }

    private func bracketed(_ t: Token) -> String {
        if let chord = t.chord {
            return "[" + chord.toString() + "]"
        } else {
            // treat as chord-comment token
            return "[*" + t.raw + "]"
        }
    }

    private func splitWithOffsets(line: String) -> [(Int, String)] {
        // keep track of starting column for each token.
        var result: [(Int, String)] = []
        var pos = 0
        var current = ""
        var currentStart = 0

        func flush() {
            if !current.isEmpty {
                result.append((currentStart, current))
                current = ""
            }
        }

        for ch in line { // iterate unicode scalars correctly via Character
            if ch == " " { // space delimits tokens, but counts toward offset
                if current.isEmpty {
                    pos += 1
                } else {
                    flush()
                    pos += 1
                    currentStart = pos
                }
            } else {
                if current.isEmpty { currentStart = pos }
                current.append(ch)
                pos += 1
            }
        }
        flush()
        return result
    }
}

#if false
import Foundation

public class ChordProReverseParserII {
    private(set) var chunks: [SongRenderChunk] = []
//    private var rootSystem: ChordRoot
    private let rootSys: RootSys
    
    public init(rootSys: RootSys) {
//        self.rootSystem = rootSystem
        self.rootSys = rootSys

    }
    
    public func toString() -> String {
        var res: String = ""

        for chunk in chunks {
            switch chunk.content {
                
            case .sectionStarted(let section, _):
                res.append("[" + section + "]\n")
                
            case .splittedline(chords: let chords, texts: let texts, plaintext: let plaintext):
                let split = SplittedLine(chords: chords, texts: texts, plainText: plaintext)
                res.append(mixSplittedLine(splittedLine: split) + "\n")
                
            default:
                break
            }
        }
        
        return res
    }
        
    public func parse(input: String) {
        var lines = [String]()
        input.enumerateLines{ (line, _) -> () in
            let cleanLine = line.replacingOccurrences(of: "\r", with: "")
            lines.append(cleanLine)
        }
        
        var lastLine: (textElement: [TextElement], isChord: Bool)?

        var cnt = lines.count
        
        // SplittedLines erzeugen
        
        for line in lines {
            cnt -= 1
            
            let curLine = isChordline(line: line)
            
            if line.starts(with: "[") && line.last == "]" {
                let s = line.index(after: line.startIndex)
                let e = line.index(before: line.endIndex)
                
                let sectionName = String(line[s..<e])
                chunks.append(SongRenderChunk(content: .sectionStarted(sectionName, 0)))
                continue
            }
            
            if curLine.isChord {
                // aktuelle Zeile sind Chords
                if let last = lastLine, last.isChord {
                    // letzte Zeile waren auch Chords, also eine einzelne Chordzeile ohne Text
                    chunks.append(SongRenderChunk(content: .splittedline(chords: last.textElement, texts: [], plaintext: "")))
                }
                // für nächste Zeile merken
                lastLine = curLine
                if cnt == 0 { chunks.append(SongRenderChunk(content: .splittedline(chords: curLine.textElement, texts: [], plaintext: ""))) }
                print("chordline")
            } else {
                // aktuelle Zeile keine Chords
                if let last = lastLine, last.isChord {
                    // letzte Zeile waren Chords, also komplette Chord/Text-Zeile
                    if !curLine.textElement.isEmpty {
                        chunks.append(SongRenderChunk(content: .splittedline(chords: last.textElement, texts: curLine.textElement, plaintext: "")))
                        print("chord/textline")
                    } else {
                        // Leerzeile, aber letzte Chordline nicht vergessen
                        chunks.append(SongRenderChunk(content: .splittedline(chords: last.textElement, texts: [], plaintext: "")))
                        chunks.append(SongRenderChunk(content: .splittedline(chords: [], texts: [], plaintext: "")))
                        print("textline(leer)")
                    }

                    // Text als erledigt merken
                    lastLine = nil
                } else  {
                    // letzte Zeile waren keine Chords, also eine einzelne Textzeile ohne Chord
                    chunks.append(SongRenderChunk(content: .splittedline(chords: [], texts: curLine.textElement, plaintext: "")))
                    print("textline")

                    // Text als erledigt merken
                    lastLine = nil
                }
            }
        }
    }
    
    private func isChordline(line: String) -> (textElement: [TextElement], isChord: Bool) {
        let spl = splitWords(line: line)
        
        var chords: [TextElement] = []
        var txts: [TextElement] = []
        var numChords: Int = 0
        var numTexts: Int = 0
        
        for word in spl {
            // falls es Chords sind
            if let chord = try? Chord.parse(word.txt, preferedGermanParsing: rootSys == .german, strict: true) {
                chords.append(TextElement(txt: "[" + chord.toString() + "]", isChordcomment: false, fontOffset: Double(word.pos), background: false, chord: chord))
                numChords += 1
            } else if word.txt == "|" {
                // wirkt wie Chord
                chords.append(TextElement(txt: word.txt, isChordcomment: false, fontOffset: Double(word.pos), background: false, chord: nil))
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
    
    /// Verbesserte Version mit Gewichtung, als Idee für später
    private func isChordlineII(line: String) -> (textElement: [TextElement], isChord: Bool) {
        let spl = splitWords(line: line)

        var chordElems: [TextElement] = []
        var textElems: [TextElement] = []
        var score: Double = 0.0

        // Regex-Vorfilter, sehr tolerant
        let chordishRegex = #"(?i)^\s*([A-GH](?:#|b|is|es)?)(?:m|maj|dim|aug)?(?:\d+|sus\\d+|add\\d+|b\\d+|#\\d+|\\^\\d+)*(?:/[A-GH](?:#|b|is|es)?)?\\s*$"#

        for word in spl {
            var raw = word.txt

            // Token säubern: eckige Klammern/ChordComments am Rand entfernen
            if raw.hasPrefix("[*"), raw.hasSuffix("]") {
                raw = String(raw.dropFirst(2).dropLast(1))
            } else if raw.hasPrefix("["), raw.hasSuffix("]") {
                raw = String(raw.dropFirst(1).dropLast(1))
            }
            // Satzzeichen am Rand entfernen (nicht #/b)
            raw = raw.trimmingCharacters(in: CharacterSet(charactersIn: ",.;:!?"))

            let looksChordish = raw.range(of: chordishRegex, options: .regularExpression) != nil

            if looksChordish, let chord = try? Chord.parse(raw, preferedGermanParsing: rootSys == .german, strict: true) {
                // als Akkord zählen
                chordElems.append(TextElement(txt: "[" + chord.toString() + "]",
                                              isChordcomment: false,
                                              fontOffset: Double(word.pos),
                                              background: false,
                                              chord: chord))
                // Punkte vergeben
                score += 1.0
                if raw.contains("/") { score += 0.25 }
                if raw.range(of: #"[0-9]"#, options: .regularExpression) != nil { score += 0.1 }
            } else {
                // als Text behandeln
                chordElems.append(TextElement(txt: word.txt, isChordcomment: false, fontOffset: Double(word.pos), background: false, chord: nil))
                // Leicht negativ werten
                let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.isEmpty || cleaned.count <= 2 {
                    score -= 0.05
                } else {
                    score -= 0.1
                }
            }

            // Textliste immer füllen (wie zuvor)
            textElems.append(TextElement(txt: word.txt, isChordcomment: false, fontOffset: Double(word.pos), background: false, chord: nil))
        }

        // Schwelle dynamisch: bei wenigen Tokens etwas toleranter
        let threshold = max(0.5, Double(spl.count) * 0.15)
        let isChord = score >= threshold

        if isChord { return (chordElems, true) }
        return (textElems, false)
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
    
    private func mixSplittedLine(splittedLine: SplittedLine) -> String {
        var txt = splittedLine.textsToString() ?? ""
        
        if txt.isEmpty {
            // aufsteigend sortiert
            var lst = 0
            for chord in splittedLine.chords.sorted(by: { $0.fontOffset < $1.fontOffset }) {
                let off = max(0, Int(chord.fontOffset) - lst)
//                print("off = \(Int(chord.fontOffset)) - \(lst)")
                txt.append(String(repeating: " ", count: off))
//                print("lst = \(chord.txt.count)\(chord.txt) + \(Int(chord.fontOffset))")
                // Chords haben schon [], Texte werden ansonsten hier zum ChordComment mit [* ...]
                let t = (chord.txt.first == "[" && chord.txt.last == "]" ? chord.txt : "[*" + chord.txt + "]")
                lst = t.count + Int(chord.fontOffset)
                lst = chord.chord == nil ? lst - 3 : lst - 2        // für Chord [] abziehen, für comment [*] abziehen
                txt += t
//                print("\(Int(chord.fontOffset)) >\(txt)<")
            }
        } else {
            // absteigend sortiert
            for chord in splittedLine.chords.sorted(by: { $0.fontOffset > $1.fontOffset }) {
                if Int(chord.fontOffset) > txt.count { txt.append(String(repeating: " ", count: Int(chord.fontOffset) - txt.count)) }
                
                // Chords haben schon [], Texte werden ansonsten hier zum ChordComment mit [* ...]
                let t = (chord.txt.first == "[" && chord.txt.last == "]" ? chord.txt : "[*" + chord.txt + "]")
                txt.insert(contentsOf: t, at: txt.index(txt.startIndex, offsetBy: Int(chord.fontOffset)))
//                print("\(Int(chord.fontOffset)) >\(txt)<")
            }
        }
        
        return txt
    }
}
#endif

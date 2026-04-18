//
//  ChordProReverseParser.swift
//  SongChords
//
//  Created by Peter Wichert on 13.11.24.
//

import Foundation

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
    public func parse(inp: String) {
        outputLines.removeAll(keepingCapacity: true)

        // alle Arten von Whitespace cleanen
        let inp1 = inp.unicodeScalars.map {
            CharacterSet.whitespaces.contains($0) ? " " : String($0)
        }.joined()
        
        let input = inp1.filter { ch in
            // Remove control and format characters, but not \n
            !(ch.isControlCharacter && ch != "\n" || ch.isFormatCharacter || ch.isNonBreakingSpace)
        }
        
        // Split lines while preserving empty lines
        var lines: [String] = []
        input.enumerateLines { line, _ in
            lines.append(line)
        }
        
        if input.hasSuffix("\n") && (lines.isEmpty || lines.last != "") {
            // enumerateLines doesn't add a trailing empty line if input ends with \n
            // add empty line explicitly
            lines.append("")
        }

        var i = 0
        while i < lines.count {
            let l = lines[i]
            let trimmed = l.trimmingCharacters(in: .whitespaces)
            let line = trimmingTrailing(l)

            // Empty line
            if trimmed.isEmpty {
                outputLines.append("")
                i += 1
                continue
            }
            
            // [Section]
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                outputLines.append(line)
                i += 1
                continue
            }
            
            let chordInfo = analyze(line: line)
            if chordInfo.isChordLine {
                // Try to pair with next line if it's not a chord line and not empty
                if i + 1 < lines.count {
                    let n = lines[i + 1]
                    let nextTrimmed = n.trimmingCharacters(in: .whitespaces)
                    let next = trimmingTrailing(n)
                    let nextInfo = analyze(line: next)
                    if !nextInfo.isChordLine && !nextInfo.tokens.isEmpty && !(nextTrimmed.hasPrefix("[") && nextTrimmed.hasSuffix("]")) {
                        // Chords over text: merge into one ChordPro line
                        let merged = mergeChord(tokens: chordInfo.tokens, text: next)
                        outputLines.append(merged)
                        i += 2
                        continue
                    }
                }
                // Chord-only line
                let merged = mergeChord(tokens: chordInfo.tokens, text: "")
                outputLines.append(merged)
                i += 1
                continue
            } else {
                // Text-only line
                outputLines.append(line)
                i += 1
                continue
            }
        }
        
        func trimmingTrailing(_ str: String) -> String {
            return str.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
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

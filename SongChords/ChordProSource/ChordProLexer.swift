//
//  ChordProLexer.swift
//  SongChords Develop
//
//  Created by Peter Wichert on 09.10.24.
//

import Foundation

enum LexerError: Error {
    case unclosedBracket
    case unclosedCurly
    case invalidCurly
    case inputTooLarge
}

public enum Token: Equatable {
    case bracketEnclosed(String)    // [C] -> "Cm"
    case curlyEnclosed(String)      // {title: My Song} -> "title: My Song"
    case text(String)               // song text -> "song text"
    case comment(String)            // #: abc -> " abc"
    case newLine                    // \n -> newLine
}

public class ChordProLexer {
    private let input: String
    private var position: String.Index

    private var tokens: [Token] = []
    
    /// Initialisiert den Lexer mit Eingabetext.
    ///
    /// - Parameter input: Der zu analysierende Text.
    /// - Throws: `LexerError.inputTooLarge`, wenn der Text größer als 50 MB ist.
    public init(input: String) throws {
        guard input.count < 50_000_000 else {
            throw LexerError.inputTooLarge
        }
        
        self.input = input
        self.position = input.startIndex
    }
    
    /// Hauptmethode, um den Eingabetext in Tokens zu zerlegen.
    ///
    /// - Returns: Eine Liste von erkannten Tokens.
    public func tokenize() -> [Token] {
        tokens = []
        
        while let ch = getChar() {
            let token: Token? = {
                switch ch {
                case "[":
                    return parseBrackets()
                case "{":
                    return parseCurly()
                case "\n":
                    return .newLine
                default:
                    pushChar()
                    return parseText()
                }
            }()
            
            if Task.isCancelled { print("cancelled"); break }

            if let token = token {
                tokens.append(token)
            }
        }
        
        return tokens
    }
    
    /// Helfermethoden zur Analyse. Alle Methoden lassen die Eingabeposition auf dem Stoppkriterium stehen.
    /// "\n" wird zurückgepusht, weil es in der Hauptschleife als eigenes Token erkannt werden muss. Grundsätzlich
    /// wird immer gepusht, wenn das Zeichen in der Hauptschleife noch erkannt werden muss.
    
    /// Falls eine Klammer nicht geschlossen wird, wird der Inhalt als regulärer Text (`.text`) behandelt.
    
    private func parseBrackets() -> Token  {
        var chord = ""
        
        // Stoppkriterium "]" und "\n"
        
        while let escaped = parseEscapedChar() {
            if let esc = escaped.esc { chord.append(esc); continue }
            guard let char = escaped.ch else { break }
            
            if char == "\n" { pushChar(); break }
            
            if char == "]" {
                return .bracketEnclosed(chord)
            }
            
            chord.append(char)
        }
        
        print("Warning: missing closing bracket [ at position \(input.distance(from: input.startIndex, to: position))")
        return .text("[" + chord)
    }
    
    private func parseCurly() -> Token {
        var directive = ""
        var stack: [Character] = []
        
        // Stoppkriterium "}" und "\n"
        
        while let escaped = parseEscapedChar() {
            if let esc = escaped.esc { directive.append(esc); continue }
            guard let char = escaped.ch else { break }
            
            if char == "\n" { pushChar(); break }
            
            if char == "{" && directive.last == "%" {
                stack.append("{")
            } else if char == "}" && !stack.isEmpty {
                stack.removeLast()
            } else if char == "}" && stack.isEmpty {
                return .curlyEnclosed(directive)
            }
            
            directive.append(char)
        }
        
        print("Warning: missing closing curly brace { at position \(input.distance(from: input.startIndex, to: position))")
        return .text("{" + directive)
    }
    
    /// Analysiert regulären Text zwischen Akkorden und Direktiven.
    /// Kommentare müssen am Zeilenanfang stehen, es dürfen whitespaces davor stehen
    private func parseText() -> Token? {
        var text = ""
        
        while let escaped = parseEscapedChar() {
            if let esc = escaped.esc { text.append(esc); continue }
            guard let char = escaped.ch else { break }
            
            // Stoppkriterium "\n"
            if char == "\n" {
                pushChar()
                break
            }
            
            // "#" oder "#:", aber nur am Zeilenanfang
            if char == "#" && text.trimmingCharacters(in: .whitespaces).isEmpty && (tokens.isEmpty || tokens.last == .newLine) {
                if let songComment = parseComment() {
                    return .comment(songComment)
                } else {
                    return nil
                }
            }
            
            // Stoppkriterium "{": Prüfen, ob ein '{' folgt und NICHT Teil von '%{' ist.
            if char == "{" && text.last != "%" {
                pushChar()
                break  // Beende das Parsen, wenn es kein '%{' ist.
            }
            // Stoppkriterium: "["
            if char == "[" {
                pushChar()
                break
            }
            
            text.append(char)
        }
        
        return .text(text)
    }
    
    private func parseComment() -> String? {
        var comment = ""
        
        // Stoppkriterium: "\n"
        
        let char = getChar()
        
        if char == ":" {
            // Kommentar-Token, Zeile bleibt erhalten
            while let char = getChar() {
                if char == "\n" { pushChar(); break }
                comment.append(char)
            }
        } else {
            // Zeile verschwindet komplett
            if char == "\n" { return nil }
            while let nextChar = getChar(), nextChar != "\n" {}
            return nil
        }
        
        return comment
    }
    
    /// Liefert entweder den nächsten "normalen" Character (ch) oder einen "escape"-Character (esc)
    /// Maskiertes \n wird überlesen
    private func parseEscapedChar() -> (ch: Character?, esc: Character?)? {
        guard let current = getChar() else { return nil }
        
        if current == "\\" {
            guard let escaped = getChar() else { return ("\\", nil) }
            if escaped == "\n" {
                return (getChar(), nil)
            }
            return (nil, escaped)
        }
        
        return (current, nil)
    }
    
    private func getChar() -> Character? {
        guard position < input.endIndex else { return  nil}

        let res = input[position]
        position = input.index(after: position)

        return res
    }
    
    private func pushChar() {
        guard position > input.startIndex else { return }
        position = input.index(before: position)
    }
}

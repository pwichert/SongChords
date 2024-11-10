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
    
    public init(input: String) throws {
        guard input.count < 10_000_000 else {
            throw LexerError.inputTooLarge
        }
        
        self.input = input
        self.position = input.startIndex
    }
    
    /// Analysiert und extrahiert Textinhalte, Akkorde und Direktiven aus dem Eingabetext.
    ///
    /// Diese Methode durchsucht den Eingabetext und gibt eine Liste von `Token`-Werten zurück, die den verschiedenen Elementen im Text entsprechen. Beendet die Verarbeitung nicht bei Fehlern.
    ///
    /// - Returns: Eine Liste von `Token`-Werten, die den analysierten Elementen entsprechen.
    ///
    /// - Important: Die Methode behandelt `%{...}` als normalen Text und erkennt Kommentare nur am Anfang einer neuen Zeile.
    ///
    /// - SeeAlso: `parseBrackets()`, `parseCurly()`, `parseText()`
    public func tokenize() -> [Token] {
        var tokens: [Token] = []
        
        while position < input.endIndex {
            let token: Token? = {
                switch input[position] {
                case "[":
                    return parseBrackets()
                case "{":
                    return parseCurly()
                case "\n":
                    advance()
                    return .newLine
                default:
                    return parseText()
                }
            }()

            if let token = token {
                tokens.append(token)
            }
        }
        
        return tokens
    }
    
    // Helfermethoden zur Analyse. Alle Methoden lassen die Eingabeposition auf dem Stoppkriterium oder "\n" stehen. Ausnahme ist der Kommentar mit "#" (nicht "#:"): die Position steht NACH dem "\n".
    
    // Falls eine Klammer nicht geschlossen wird, wird der Inhalt als regulärer Text (`.text`) behandelt.

    private func parseBrackets() -> Token  {
        advance() // Überspringt die öffnende Klammer
        var chord = ""
        
        // Stoppkriterium "]" und "\n"

        while position < input.endIndex {
            let char = input[position]

            if char == "\n" { break }

            if char == "]" {
                advance() // Überspringt die schließende Klammer
                return .bracketEnclosed(chord)
            }

            chord.append(char)
            advance()
        }
        
        print("Warning: missing closing bracket [ at position \(input.distance(from: input.startIndex, to: position))")
        return .text("[" + chord)
    }
    
    private func parseCurly() -> Token {
        advance() // Überspringt die öffnende geschweifte Klammer
        var directive = ""
        var stack: [Character] = []

        // Stoppkriterium "}" und "\n"

        while position < input.endIndex {
            let char = input[position]
            
            if char == "\n" { break }

            if char == "{" && directive.last == "%" {
                stack.append("{")
            } else if char == "}" && !stack.isEmpty {
                stack.removeLast()
            } else if char == "}" && stack.isEmpty {
                advance() // Überspringt die schließende Klammer
                return .curlyEnclosed(directive)
            }

            directive.append(char)
            advance()
        }
        
        print("Warning: missing closing curly brace { at position \(input.distance(from: input.startIndex, to: position))")
        return .text("{" + directive)
    }
    
    /// Analysiert und extrahiert Textinhalte, die zwischen Akkorden und Direktiven liegen, und erkennt Kommentare im Songtext.
    ///
    /// Die Methode durchsucht den Eingabetext und gibt entweder einen `Token.text`-Wert zurück, wenn regulärer Text gefunden wird, oder `Token.comment`, wenn eine Kommentarzeile (beginnend mit `#:`) erkannt wird. Außerdem behandelt sie `{}`- und `[]`-Strukturen korrekt, indem sie den Text-Parsing-Prozess beendet, sobald solche Strukturen gefunden werden.
    ///
    /// - Returns:
    /// Ein `Token`, der entweder regulären Text (`.text`) oder einen Kommentar (`.comment`) enthält. Gibt `nil` zurück, wenn mit `#` die Zeile komplett ignoriert werden soll.
    ///
    /// - Important:
    /// Die Methode erkennt nur Kommentare, die am Anfang einer neuen Zeile beginnen und mit einem  `#:` eingeleitet werden. Variablen mit `%{...}` werden als normaler Text behandelt, nicht ersetzt und nicht als Stoppkriterium interpretiert.
    ///
    /// - Precondition:
    /// Die Methode erwartet, dass der Lexer bereits an einer gültigen Textposition startet. Sie wird nicht aufgerufen, wenn `{` oder `[` direkt an der aktuellen Position stehen.
    ///
    private func parseText() -> Token? {
        var text = ""
        let isNewLine: Bool = position == input.startIndex || input[input.index(before: position)] == "\n"
        
        while position < input.endIndex {
            let char = input[position]
            
            // Stoppkriterium "\n"
            if char == "\n" { break }

            // # oder #:
            if char == "#" && text.trimmingCharacters(in: .whitespaces).isEmpty && isNewLine {
                if let songComment = parseComment() {
                    return .comment(songComment)
                } else {
                    return nil
                }
            }
            
            // Stoppkriterium "{": Prüfen, ob ein '{' folgt und NICHT Teil von '%{' ist.
            if char == "{" && (position == input.startIndex || input[input.index(before: position)] != "%") {
                break  // Beende das Parsen, wenn es kein '%{' ist.
            }
            // Stoppkriterium: "["
            if char == "[" {
                break
            }
            
            text.append(char)
            advance()
        }
        
        return .text(text)
    }
    
    private func parseComment() -> String? {
        advance()   // "#"
        var comment = ""
        
        // Stoppkriterium: "\n"

        if input[position] == ":" {
            advance()   // ":"
            // Kommentar-Token
            while position < input.endIndex && input[position] != "\n" {
                comment.append(input[position])
                advance()
            }
        } else {
            // Zeile verschwindet komplett
            while position < input.endIndex && input[position] != "\n" {
                advance()
            }
            advance()   // "\n"
            return nil
        }
        
        return comment
    }
    
    private func advance() {
        if position < input.endIndex {
            position = input.index(after: position)
        } else {
            print("Error: End of input reached")
        }
    }
}

//
//  ChordProLexer.swift
//  SongChords Develop
//
//  Created by Peter Wichert on 09.10.24.
//

import Foundation

nonisolated
private enum LexerSymbol: Equatable {
    case BracketOpen        // [
    case BracketClose       // ]
    case CurlyOpen          // {
    case CurlyOpenPercent   // %{
    case CurlyClose         // }
    case Comment            // #
    case CommentHidden      // #:
    case Char(Character)
    case NewLine            // \n
}

public enum Token: Equatable {
    case bracketEnclosed(String)    // [C] -> "Cm"
    case curlyEnclosed(String)      // {title: My Song} -> "title: My Song"
    case text(String)               // song text -> "song text"
    case comment(String)            // # abc -> " abc"
    case commentHidden(String)      // #: abc -> " abc"
    case newLine                    // \n -> newLine
}

nonisolated
private enum LexerMode: Equatable {
    case normal
    case raw
}

nonisolated
public class ChordProLexer {
    private let input: String
    private var position: String.Index
        
    private var commentAllowed: Bool = true
    private var sym: LexerSymbol?
    
    private var line = ""
    
    public init(input: String) {
        self.input = input
        self.position = self.input.startIndex
        advance()
    }
    
    @concurrent
    public func tokensAsStream() async throws -> AsyncThrowingStream<Token, Error> {
        
        AsyncThrowingStream { continuation in            
            continuation.onTermination = { termination in
//                print("token stream terminated:", termination)
            }
            
            let input = self.input

            Task {
//                print("tokensAsStream:", Thread.currentThread)

                let lexer = ChordProLexer(input: input)
    
                do {
                    while let token = lexer.nextToken() {
                        try Task.checkCancellation()
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func nextToken() -> Token? {
        let token = nextToken_()
        
//        if let token = token { print(token) } else { print("nil") }
        
        #if false
        switch token {
        case .bracketEnclosed(let str): line.append("[" + str + "]")
        case .curlyEnclosed(let str): line.append("{" + str + "}")
        case .text(let str): line.append(str)
        case .comment(let str): line.append(str)
        case .commentHidden(let str): line.append(str)
        case .newLine: print(line); line = ""
        case .none: if line.count > 0 { print(line) }
        }
        #endif
        
        return token
    }
    
    private func nextToken_() -> Token? {
        guard let symbol = sym else { return nil }
                
        if commentAllowed && symbol != .Comment && symbol != .CommentHidden {
            commentAllowed = false
        }

        switch symbol {
        case .BracketOpen:
            advance()
            let tok = Token.bracketEnclosed(textToSymbol(stopSym: .BracketClose))
            advance()
            return tok
            
        case .CurlyOpen:
            advance()
            let tok = Token.curlyEnclosed(textToSymbol(stopSym: .CurlyClose, raw: true))     // \ und %{ soll hier erhalten bleiben für processReplace()
            advance()
            return tok

        case .Comment:
            if commentAllowed {
                advance()
                let tok = Token.comment(restOfLine())
                advance()
                return tok
            } else {
                return .text(textToNewline())
            }
            
        case .CommentHidden:
            if commentAllowed {
                advance()
                let tok = Token.commentHidden(restOfLine())
                advance()
                return tok
            } else {
                return .text(textToNewline())
            }
            
        case .NewLine:
            commentAllowed = true
            advance()
            return .newLine
            
        // Text und sinnlos im Text erscheinende schließende Klammern bleiben Text
        // %{ bleiben Text, weil sie im Parser verarbeitet werden
        case .Char(_), .BracketClose, .CurlyClose, .CurlyOpenPercent:
            let tok = Token.text(textToNewline())
            return tok
        }
    }
    
    // Token für Parser.processReplace(), Ersetzen von %{ variable }
    func nextVariableToken() -> Token? {
        guard let symbol = sym else { return nil }
                
        switch symbol {
        case .CurlyOpenPercent:
            advance()
            let tok = Token.curlyEnclosed(textToSymbol(stopSym: .CurlyClose))
            advance()
            return tok

        default:
            return .text(textToSymbol(stopSym: .CurlyOpenPercent))
        }
    }

    // Text bis Zeilenende
    private func restOfLine() -> String {
        return textToSymbol(stopSym: .NewLine)
    }
    
    // Text bis Zeilenende, aber max. bis Chord oder Direktive
    // Rückkehr mit begrenzendem Symbol
    private func textToNewline() -> String {
        var res: String = ""
        
        while let symbol = sym {
            switch symbol {
            // begrenzendes Symbol
            case .BracketOpen, .CurlyOpen, .NewLine:
                return res
            default:
                res.append(symbolLiteral(symbol))
                advance()
            }
            
        }
        
        return res
    }
    
    // Text bis Stoppsymbol
    // Rückkehr mit Symbol
    private func textToSymbol(stopSym: LexerSymbol, raw: Bool = false) -> String {
        var res: String = ""
        var level: Int = 0
        let startIndex = input.index(before: position)
        
        // im raw-Modus wird der unescaped-Text, also mit "\", geliefert
        
        while let symbol = sym {
            if level <= 0 && symbol == stopSym { if raw { return String(input[startIndex..<input.index(before: position)]) } else { return res }}
            if stopSym == .CurlyClose && symbol == .CurlyOpenPercent { level += 1 }
            if symbol == .CurlyClose { level -= 1 }

            res.append(symbolLiteral(symbol))
            advance()
        }
        
        if raw { return String(input[startIndex..<input.index(before: position)]) } else { return res }
    }
    
    private func advance() {
        sym = getSymbol_()
        #if false
        if let sym = sym {
            if case .Char(let ch) = sym {
                print(ch, terminator:  " ")
            } else {
                print("SYM(" + symbolLiteral(sym) + ")", terminator: " ")
            }
        } else { print("nil") }
        #endif
    }
    
    private func getSymbol_() -> LexerSymbol? {
        while let current = getChar() {
            // ungültige / unsichtbare Zeichen behandeln
            if current != "\n" && current.isControlCharacter { continue }
            if current.isFormatCharacter { continue }
            if current.isNonBreakingSpace { return .Char(" ") }

            switch current {
            case "\\":
                guard let escaped = getChar() else { return .Char(current) }
                if escaped == "\n" { continue }
                return .Char(escaped)
                
            case "%":
                guard let curlyopen = getChar() else { return .Char(current) }
                if curlyopen == "{" { return .CurlyOpenPercent}
                pushChar()
                return .Char(current)
                
            case "#":
                guard let commenthidden = getChar() else { return .Char(current) }
                if commenthidden == ":" { return .CommentHidden}
                pushChar()
                return .Comment

            case "[": return .BracketOpen
            case "]": return .BracketClose
            case "{": return .CurlyOpen
            case "}": return .CurlyClose
            case "\n": return .NewLine
            case "\r": continue     // sicher ist sicher :-)
            default: return .Char(current)
            }
        }
        
        return nil
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
    
    private func symbolLiteral(_ symbol: LexerSymbol) -> String {
        switch symbol {
        case .BracketOpen: return "["
        case .BracketClose: return "]"
        case .CurlyOpen: return "{"
        case .CurlyOpenPercent: return "%{"
        case .CurlyClose: return "}"
        case .Comment: return "#"
        case .CommentHidden: return "#:"
        case .Char(let c): return String(c)
        case .NewLine: return "\n"
        }
    }
}

extension Character {
    nonisolated
    var isControlCharacter: Bool {
        unicodeScalars.allSatisfy {
            $0.properties.generalCategory == .control
        }
    }

    nonisolated
    var isFormatCharacter: Bool {
        unicodeScalars.allSatisfy {
            $0.properties.generalCategory == .format
        }
    }

    nonisolated
    var isNonBreakingSpace: Bool {
        unicodeScalars.contains {
            $0.value == 0x00A0 || $0.value == 0x202F
        }
    }
}

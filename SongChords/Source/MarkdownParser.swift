//
//  MarkdownParser.swift
//  SongChords
//
//  Created by Peter Wichert on 26.01.26.
//

import SwiftUI

enum MDSpan: Identifiable {
    case text(String)
    case bold(String)   // **bold**
    case code(String)   // `code`
    case icon(String)   // {icon:SF Symbol name}

    var id: UUID { UUID() }
}

enum MDNode: Identifiable {
    case h1([MDSpan])               // #
    case h2([MDSpan])               // ##
    case bullet([MDSpan])           // *
    case hyphen([MDSpan])           // -
    case enumeration([MDSpan], Int) // *1 *2 ... *9
    case quote([MDSpan])            // >
    case paragraph([MDSpan])
    case divider                    // ---
    case spacer(CGFloat)            // newline

    var id: UUID { UUID() }
}

struct MarkdownParser {

    static func parse(_ text: String) -> [MDNode] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { line in
                if line == "---" { return .divider }
                if line.isEmpty { return .spacer(8) }

                if line.hasPrefix("## ") {
                    return .h2(InlineParser.parse(String(line.dropFirst(3))))
                }
                if line.hasPrefix("# ") {
                    return .h1(InlineParser.parse(String(line.dropFirst(2))))
                }
                if line.hasPrefix("*") {
                    if line.hasPrefix("* ") {
                        return .bullet(InlineParser.parse(String(line.dropFirst(2))))
                    } else if line.count > 3 {
                        let num = line.dropFirst(1).first
                        let hasDelim = line.dropFirst(2).first?.isWhitespace ?? false
                        if let num, hasDelim, num.isNumber, let d = Int(String(num)) {
                            return .enumeration(InlineParser.parse(String(line.dropFirst(3))), d)
                        }
                    }
                }
                if line.hasPrefix("- ") {
                    return .hyphen(InlineParser.parse(String(line.dropFirst(2))))
                }
                if line.hasPrefix("> ") {
                    return .quote(InlineParser.parse(String(line.dropFirst(2))))
                }
                return .paragraph(InlineParser.parse(line))
            }
    }
}

struct InlineParser {

    static func parse(_ text: String) -> [MDSpan] {
        var spans: [MDSpan] = []
        var buffer = ""
        var i = text.startIndex

        func flush() {
            if !buffer.isEmpty {
                spans.append(.text(buffer))
                buffer = ""
            }
        }

        while i < text.endIndex {

            // **bold**
            if text[i] == "*",
               let n1 = text.index(i, offsetBy: 1, limitedBy: text.endIndex),
               n1 < text.endIndex,
               text[n1] == "*" {

                let start = text.index(i, offsetBy: 2)
                if let end = text[start...].range(of: "**")?.lowerBound {
                    flush()
                    let bold = String(text[start..<end])
                    spans.append(.bold(bold))
                    i = text.index(end, offsetBy: 2)
                    continue
                }
            }

            // `code`
            if text[i] == "`" {
                let start = text.index(after: i)
                if let end = text[start...].firstIndex(of: "`") {
                    flush()
                    let code = String(text[start..<end])
                    spans.append(.code(code))
                    i = text.index(after: end)
                    continue
                }
            }
            
            // {icon:name}
            if text[i] == "{",
               let close = text[i...].firstIndex(of: "}") {

                let token = text[text.index(after: i)..<close]

                if token.hasPrefix("icon:") {
                    flush()
                    let name = token.dropFirst(5)
                    spans.append(.icon(String(name)))
                    i = text.index(after: close)
                    continue
                }
            }

            buffer.append(text[i])
            i = text.index(after: i)
        }

        flush()
        return spans
    }
}

struct MarkdownView: View {
    let nodes: [MDNode]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(nodes) { node in
                switch node {
                case .h1(let spans):
                    spanLine(spans)
                        .font(.title).bold().padding(.top, 8)
                    
                case .h2(let spans):
                    spanLine(spans)
                        .font(.headline).bold().padding(.top, 6)
                    
                case .bullet(let spans):
                    HStack(alignment: .top) {
                        Text("•")
                        spanLine(spans)
                    }
                    
                case .hyphen(let spans):
                    HStack(alignment: .top) {
                        Text("-")
                        spanLine(spans)
                    }

                case .enumeration(let spans, let num):
                    HStack(alignment: .top) {
                        Text(String("\(num)."))
                        spanLine(spans)
                    }

                case .quote(let spans):
                    spanLine(spans)
                        .italic()
                        .padding(.leading, 10)
                        .overlay(Rectangle().frame(width: 3).foregroundColor(.secondary), alignment: .leading)
                    
                case .paragraph(let spans):
                    spanLine(spans)
                    
                case .divider:
                    Divider().padding(.vertical, 8)
                    
                case .spacer(let h):
                    Spacer().frame(height: h)
                }
            }
        }
    }
    
    func spanLine(_ spans: [MDSpan]) -> Text {
        spans.reduce(Text("")) { result, span in
            switch span {
            case .text(let s):
                return Text("\(result)\(s)")
                
            case .bold(let s):
                let b = Text(s).bold()
                return Text("\(result)\(b)")
                
            case .code(let s):
                var attr = AttributedString(s)
                attr.backgroundColor = Color.secondary.opacity(0.15)
                attr.font = .footnote.monospaced()
                let txt = Text(attr)
                return Text("\(result)\(txt)")
                
            case .icon(let name):
                let i = Text(Image(systemName: name))
                return Text("\(result)\(i)")
            }
        }
    }
}

//
//  DirectiveManager.swift
//  SongChords Develop
//
//  Created by Peter Wichert on 04.11.24.
//

// Direktiventypen, die möglicherweise in einem System vorkommen könnten
enum DirectiveType: String, CaseIterable {
    case title
    case subtitle
    case artist
    case composer
    case lyricist
    case copyright
    case album
    case year
    case key
    case time
    case tempo
    case duration
    case capo
    case meta
    
    case comment
    case comment_italic
    case comment_box
    
    case start_of_verse
    case end_of_verse
    case start_of_bridge
    case end_of_bridge
    case start_of_chorus
    case end_of_chorus
    case start_of_tab
    case end_of_tab
    
    case columns
    case column_break
    case transpose
    case new_page
}

enum DirectiveNamesSpecial: String, CaseIterable {
    case key_actual
    case key_from
}

// Verwaltungsklasse für Direktiven
class DirectiveManager {
    // Dictionary zur Speicherung der Direktiven und ihrer Werte
    private var directives: [DirectiveType: String] = [:]
    
    private(set) var transpose: Int = 0
    private(set) var columns: Int = 1
    private(set) var duration: Int = 0

    // Abkürzungen für die verschiedenen Direktiven
    private let abbreviations: [String: DirectiveType] = [
        "t": .title,
        "st": .subtitle,
        "col": .columns,
        "colb": .column_break,
        "np": .new_page,
        "c": .comment,
        "ci": .comment_italic,
        "cb": .comment_box,
        "highlight": .comment,
        "soc": .start_of_chorus,
        "eoc": .end_of_chorus,
        "sob": .start_of_bridge,
        "eob": .end_of_bridge,
        "sov": .start_of_verse,
        "eov": .end_of_verse,
        "sot": .start_of_tab,
        "eot": .end_of_tab
    ]
    
    // Fügt eine Direktive hinzu, entweder als vollständigen Namen oder als Abkürzung
    func addDirective(_ input: String) -> DirectiveType? {
        let arrWithLabel = delimitedStringToArray(str: input)
        let arr = arrWithLabel.arr
        let label = arrWithLabel.label
            
        if arr.count == 0 { return nil }
        let dir = arr[0].trimmingCharacters(in: .whitespaces).lowercased()
        var value: String?
        
        if arr.count >= 2 {
            value = arr[1].trimmingCharacters(in: .whitespaces)
        }

        if let label { value = label }

        if let directive = parseDirective(dir) {
            switch directive {
            case .transpose:
                if let value, let intval = robustStringToInt(value), intval >= -11 && intval <= 11 {
                    transpose = intval
                    directives[.transpose] = String(transpose)
//                    print("\(directive) = <\(intval)>")
                } else {
                    return nil
                }

            case .duration:
                if let value, let intval = timeVal(timeStr: value), intval >= 0 && intval <= 5000 {
                    duration = intval
                    directives[.duration] = String(duration)
//                    print("\(directive) = <\(intval)>")
                } else {
                    return nil
                }

            case .columns:
                if let value, let intval = robustStringToInt(value), intval >= 1 && intval <= 4 {
                    columns = intval
                    directives[.columns] = String(columns)
//                    print("\(directive) = <\(intval)>")
                } else {
                    return nil
                }
                
            default:
                directives[directive] = value
//                print("\(directive) = <\(value ?? "")>")
            }
            
            return directive
        } else {
            return nil
        }
    }
    
    // Gibt eine Direktive zurück, wenn sie existiert
    func getDirective(_ input: String) -> String? {
        if let directive = parseDirective(input) {
            return directives[directive]
        }
        return nil
    }
    
    // Methode zum Parsen eines Eingabewerts und Umwandeln in den passenden `DirectiveType`
    private func parseDirective(_ input: String) -> DirectiveType? {
        // Prüfen, ob es sich um eine vollständige Direktive oder Abkürzung handelt
        if let directive = DirectiveType(rawValue: input.lowercased()) {
            return directive
        } else if let directive = abbreviations[input.lowercased()] {
            return directive
        }
        return nil
    }
    
    // Liste aller gespeicherten Direktiven als String
    func listDirectives() -> String {
        return directives.map { "\($0.key.rawValue): \($0.value)" }.joined(separator: ", ")
    }
    
    // Beim ersten Vorkommen von ":" oder " " trennen und zwei Strings liefern. Optional noch ein "label"
    private func delimitedStringToArray(str: String) -> (arr: [String], label: String?) {
        let posColon = str.firstIndex(of: ":")
        let posBlank = str.firstIndex(of: " ")
                
        let pos = min(posColon ?? str.endIndex, posBlank ?? str.endIndex)
        if pos == str.endIndex { return ([str], nil) }
        let pos1 = str.index(after: pos)
        if pos1 == str.endIndex { return ([str], nil) }
        
        let dir = String(str[str.startIndex..<pos])
        let arg = String(str[pos1..<str.endIndex])
        var labelVal: String?
        
        // testen auf {start_of_verse: Verse 1} oder {start_of_verse: label="Verse 1"}
        if let eqpos = arg.firstIndex(of: "=") {
            let label = String(arg[..<eqpos]).trimmingCharacters(in: .whitespaces)
            
            if label.lowercased() == "label" {
                let valStart = arg.index(after: eqpos)
                if valStart != arg.endIndex {
                    labelVal = String(arg[valStart..<arg.endIndex]).trimmingCharacters(in: .whitespaces)
                    if labelVal!.count > 1 && labelVal!.first == "\"" && labelVal!.last == "\"" {
                        labelVal!.removeLast()
                        labelVal!.removeFirst()
                    }
                }
            }
        }
        
        return ([dir, arg], labelVal)
    }
    
    private func robustStringToInt(_ input: String?) -> Int? {
        guard let input = input else {
            return nil
        }
        
        // Entfernt unerwünschte Leerzeichen und kontrolliert, ob der String leer ist
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInput.isEmpty {
            return nil
        }
        
        // Versucht, den Wert als `Int` zu konvertieren
        if let intValue = Int(trimmedInput) {
            return intValue
        } else {
            return nil
        }
    }
    
    private func timeVal(timeStr: String) -> Int? {
        let arr = timeStr.components(separatedBy: ":")
        var secs: Int?
        var minutes: Int?
        var hours: Int?
        
        if arr.count == 3 {
            hours = robustStringToInt(arr[0])
            minutes = robustStringToInt(arr[1])
            secs = robustStringToInt(arr[2])
            if let hours = hours, hours >= 0, let minutes = minutes, minutes >= 0, minutes < 60, let secs = secs, secs >= 0, secs < 60 {
                return hours * 60 * 60 + minutes * 60 + secs
            } else {
                return nil
            }
        }
        if arr.count == 2 {
            minutes = robustStringToInt(arr[0])
            secs = robustStringToInt(arr[1])
            if let minutes = minutes, minutes >= 0, minutes < 60, let secs = secs, secs >= 0, secs < 60 {
                return minutes * 60 + secs
            } else {
                return nil
            }
        }
        if arr.count == 1 {
            secs = robustStringToInt(arr[0])
            if let secs = secs, secs >= 0, secs < 60 {
                return secs
            } else {
                return nil
            }
        }
        
        return nil
    }
}

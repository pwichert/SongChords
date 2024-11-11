//
//  ViewModel.swift
//  SongChords
//
//  Created by Peter Wichert on 11.11.24.
//

import SwiftUI

@Observable
public class ViewModel {
    public init() {}
        
#if os(macOS)
    typealias UIFont = NSFont
#endif
    
    var isGermanNotation: Bool = false

    var processingTask: Task<Void, Never>?  // Task, die bei Änderungen neu gestartet werden kann
    
    var headerUIFont: UIFont {
        return UIFont.systemFont(ofSize: headersize, weight: .bold)
    }

    var headerPDFUIFont: UIFont {
        return UIFont.systemFont(ofSize: headersizepdf, weight: .bold)
    }
    
    var txtUIFont: UIFont {
        return UIFont.monospacedSystemFont(ofSize: txtsize, weight: .regular)
    }

    var txtPDFUIFont: UIFont {
        return UIFont.monospacedSystemFont(ofSize: txtsizepdf, weight: .regular)
    }

    var chordUIFont: UIFont {
        return UIFont.monospacedSystemFont(ofSize: chordsize, weight: .bold)
    }

    var chordPDFUIFont: UIFont {
        return UIFont.monospacedSystemFont(ofSize: chordsizepdf, weight: .bold)
    }
    
    var headersizepdf: Double = UserDefaults.standard.double(forKey: "set_headersizepdf") == 0.0 ? 12.0 : UserDefaults.standard.double(forKey: "set_headersizepdf")
    { didSet { UserDefaults.standard.set(headersizepdf, forKey: "set_headersizepdf") }}

    var headersize: Double = UserDefaults.standard.double(forKey: "set_headersize") == 0.0 ? 12.0 : UserDefaults.standard.double(forKey: "set_headersize")
    { didSet { UserDefaults.standard.set(headersize, forKey: "set_headersize") }}

    var txtsize: Double = UserDefaults.standard.double(forKey: "set_textsize") == 0.0 ? 14.0 : UserDefaults.standard.double(forKey: "set_textsize")
    { didSet { UserDefaults.standard.set(txtsize, forKey: "set_textsize") }}
    
    var txtsizepdf: Double = UserDefaults.standard.double(forKey: "set_textsizepdf") == 0.0 ? 14.0 : UserDefaults.standard.double(forKey: "set_textsizepdf")
    { didSet { UserDefaults.standard.set(txtsizepdf, forKey: "set_textsizepdf") }}
    
    var chordsize: Double = UserDefaults.standard.double(forKey: "set_chordsize") == 0.0 ? 14.0 : UserDefaults.standard.double(forKey: "set_chordsize")
    { didSet { UserDefaults.standard.set(chordsize, forKey: "set_chordsize") }}
    
    var chordsizepdf: Double = UserDefaults.standard.double(forKey: "set_chordsizepdf") == 0.0 ? 14.0 : UserDefaults.standard.double(forKey: "set_chordsizepdf")
    { didSet { UserDefaults.standard.set(chordsizepdf, forKey: "set_chordsizepdf") }}
}

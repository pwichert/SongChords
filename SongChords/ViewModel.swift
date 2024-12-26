//
//  ViewModel.swift
//  SongChords
//
//  Created by Peter Wichert on 11.11.24.
//

import SwiftUI

enum DisplayMode: Int, Codable {
    case light = 1
    case dark
    case automatic
}

@Observable
public final class ViewModel {
    public init() {}
    
#if os(macOS)
    typealias UIFont = NSFont
#endif
        
    var isGermanNotation: Bool = UserDefaults.standard.bool(forKey: "set_isGermanNotation")
    { didSet { UserDefaults.standard.set(isGermanNotation, forKey: "set_isGermanNotation") }}

    var hidechords: Bool = UserDefaults.standard.bool(forKey: "set_hidechords")
    { didSet { UserDefaults.standard.set(hidechords, forKey: "set_hidechords") }}

    var textfollowschords: Bool = UserDefaults.standard.bool(forKey: "set_textfollowschords")
    { didSet { UserDefaults.standard.set(textfollowschords, forKey: "set_textfollowschords") }}

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

    var headersize: Double = UserDefaults.standard.double(forKey: "set_headersize") == 0.0 ? 14.0 : UserDefaults.standard.double(forKey: "set_headersize")
    { didSet { UserDefaults.standard.set(headersize, forKey: "set_headersize") }}

    var txtsize: Double = UserDefaults.standard.double(forKey: "set_textsize") == 0.0 ? 16.0 : UserDefaults.standard.double(forKey: "set_textsize")
    { didSet { UserDefaults.standard.set(txtsize, forKey: "set_textsize") }}
    
    var txtsizepdf: Double = UserDefaults.standard.double(forKey: "set_textsizepdf") == 0.0 ? 14.0 : UserDefaults.standard.double(forKey: "set_textsizepdf")
    { didSet { UserDefaults.standard.set(txtsizepdf, forKey: "set_textsizepdf") }}
    
    var chordsize: Double = UserDefaults.standard.double(forKey: "set_chordsize") == 0.0 ? 16.0 : UserDefaults.standard.double(forKey: "set_chordsize")
    { didSet { UserDefaults.standard.set(chordsize, forKey: "set_chordsize") }}
    
    var chordsizepdf: Double = UserDefaults.standard.double(forKey: "set_chordsizepdf") == 0.0 ? 14.0 : UserDefaults.standard.double(forKey: "set_chordsizepdf")
    { didSet { UserDefaults.standard.set(chordsizepdf, forKey: "set_chordsizepdf") }}
    
    var linespacing: Double = UserDefaults.standard.double(forKey: "set_linespacing") == 0.0 ? 4.0 : UserDefaults.standard.double(forKey: "set_linespacing")
    { didSet { UserDefaults.standard.set(linespacing, forKey: "set_linespacing") }}
    
    var linespacingpdf: Double = UserDefaults.standard.double(forKey: "set_linespacingpdf") == 0.0 ? 4.0 : UserDefaults.standard.double(forKey: "set_linespacingpdf")
    { didSet { UserDefaults.standard.set(linespacingpdf, forKey: "set_linespacingpdf") }}
    
    var displayMode: DisplayMode = DisplayMode(rawValue: UserDefaults.standard.integer(forKey: "set_displayMode")) ?? DisplayMode.automatic
    { didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "set_displayMode") }}

    // Printing
    
    var mediabox: String = UserDefaults.standard.string(forKey: "prt_mediabox") ?? ""
    { didSet { UserDefaults.standard.set(mediabox, forKey: "prt_mediabox") }}

    var printingscale: Double = UserDefaults.standard.double(forKey: "prt_printingscale") == 0.0 ? 70 : UserDefaults.standard.double(forKey: "prt_printingscale")
    { didSet { UserDefaults.standard.set(printingscale, forKey: "prt_printingscale") }}

    var marginleft: Double = UserDefaults.standard.double(forKey: "prt_marginleft") == 0.0 ? 40.0 : UserDefaults.standard.double(forKey: "prt_marginleft")
    { didSet { UserDefaults.standard.set(marginleft, forKey: "prt_marginleft") }}

    var marginright: Double = UserDefaults.standard.double(forKey: "prt_marginright") == 0.0 ? 40.0 : UserDefaults.standard.double(forKey: "prt_marginright")
    { didSet { UserDefaults.standard.set(marginright, forKey: "prt_marginright") }}

    var margintop: Double = UserDefaults.standard.double(forKey: "prt_margintop") == 0.0 ? 40.0 : UserDefaults.standard.double(forKey: "prt_margintop")
    { didSet { UserDefaults.standard.set(margintop, forKey: "prt_margintop") }}

    var marginbottom: Double = UserDefaults.standard.double(forKey: "prt_marginbottom") == 0.0 ? 40.0 : UserDefaults.standard.double(forKey: "prt_marginbottom")
    { didSet { UserDefaults.standard.set(marginbottom, forKey: "prt_marginbottom") }}

    public func getVersion() -> String {
        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? ""
        let appVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
        let appBuild = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
        
        return appName + " " + appVersion + "." + appBuild
    }
}

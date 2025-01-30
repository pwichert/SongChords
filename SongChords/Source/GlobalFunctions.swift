//
//  GlobalFunctions.swift
//  SongChords
//
//  Created by Peter Wichert on 31.01.25.
//

import SwiftUI

class GlobalFunctions {
    static func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: round(timeInterval)) ?? "00:00"
    }
}

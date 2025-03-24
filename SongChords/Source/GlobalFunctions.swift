//
//  GlobalFunctions.swift
//  SongChords
//
//  Created by Peter Wichert on 31.01.25.
//

import SwiftUI

public class GlobalFunctions {
    public static func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: round(timeInterval)) ?? "00:00"
    }
    
    public static func mp3Path() throws -> URL {
        let fileManager = FileManager.default
        let dest = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return dest.appendingPathComponent("mp3")
    }
}

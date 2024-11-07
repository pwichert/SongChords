//
//  Item.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

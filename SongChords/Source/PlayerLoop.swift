//
//  PlayerLoop.swift
//  SongChords
//
//  Created by Peter Wichert on 28.01.25.
//

import SwiftUI

@Observable
class PlayerLoop: Codable, Identifiable, Hashable {
    static func == (lhs: PlayerLoop, rhs: PlayerLoop) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    private(set) var id = UUID()
    var start: TimeInterval = 0
    var stop: TimeInterval = 0
    var title: String = ""
        
    init(start: TimeInterval, stop: TimeInterval, title: String) {
        self.id = UUID()
        self.start = start
        self.stop = stop
        self.title = title
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        start = try container.decode(TimeInterval.self, forKey: .start)
        stop = try container.decode(TimeInterval.self, forKey: .stop)
        title = try container.decode(String.self, forKey: .title)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(start, forKey: .start)
        try container.encode(stop, forKey: .stop)
        try container.encode(title, forKey: .title)
    }
    
    enum CodingKeys: CodingKey {
        case id
        case start
        case stop
        case title
    }
    
    func contains(position: TimeInterval) -> Bool {
        position >= start && position < stop
    }
    
    func isValid(duration: TimeInterval) -> Bool {
        let maxLoopStop = max(0, duration - 1.2)
        let minLoopDuration = 1.2
        return stop > 0.0 && stop < maxLoopStop && start < stop && stop - start > minLoopDuration
    }
}

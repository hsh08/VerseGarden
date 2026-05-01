//
//  Item.swift
//  VerseGarden
//
//  Created by 한상혁 on 5/1/26.
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

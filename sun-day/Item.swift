//
//  Item.swift
//  sun-day
//
//  Created by Peyton Randolph on 2/23/26.
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

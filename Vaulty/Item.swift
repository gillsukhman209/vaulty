//
//  Item.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
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

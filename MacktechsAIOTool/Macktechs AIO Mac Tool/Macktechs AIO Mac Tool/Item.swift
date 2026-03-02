//
//  Item.swift
//  Macktechs AIO Mac Tool
//
//  Created by Matt G on 3/1/26.
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

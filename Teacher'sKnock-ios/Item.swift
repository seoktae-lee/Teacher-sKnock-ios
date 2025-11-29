//
//  Item.swift
//  Teacher'sKnock-ios
//
//  Created by 이석태 on 11/29/25.
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

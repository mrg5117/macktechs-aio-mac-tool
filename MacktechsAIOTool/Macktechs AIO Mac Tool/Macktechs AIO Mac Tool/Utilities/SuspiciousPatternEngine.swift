//
//  SuspiciousPatternEngine.swift
//  Macktechs AIO Mac Tool
//
//  Read-only pattern matching for known PUP/adware keywords (from browser_health_check.sh spec).
//

import Foundation

enum SuspiciousPatternEngine {
    static let patterns: [String] = [
        "mackeeper",
        "mackeepr",
        "advancedmaccleaner",
        "searchmarquis",
        "search baron",
        "searchbaron",
        "chilltab",
        "weknow",
        "anysearch",
        "mybrowserhelper",
    ]

    static func isSuspicious(_ text: String) -> Bool {
        let lower = text.lowercased()
        return patterns.contains { lower.contains($0) }
    }
}

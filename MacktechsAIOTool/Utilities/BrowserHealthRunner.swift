//
//  BrowserHealthRunner.swift
//  Macktechs AIO Mac Tool
//
//  Runs the bundled browser_health_check.sh script (read-only). Used by Browser Health Check tab.
//

import Foundation

struct BrowserHealthRunner {
    /// Runs the bundled script on a background queue and calls completion on the main queue with combined stdout + stderr.
    static func run(completion: @escaping (String) -> Void) {
        runBrowserHealthScript(completion: completion)
    }
}

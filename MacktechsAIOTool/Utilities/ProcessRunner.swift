//
//  ProcessRunner.swift
//  Macktechs AIO Tool
//
//  Runs browser_health_check.sh from the app bundle and returns combined stdout + stderr.
//

import Foundation

/// Locates and runs browser_health_check.sh from the app bundle. Output is returned on the main queue.
func runBrowserHealthScript(completion: @escaping (String) -> Void) {
    let queue = DispatchQueue(label: "com.macktechs.browserhealth", qos: .userInitiated)
    queue.async {
        let result = runBrowserHealthScriptSync()
        DispatchQueue.main.async {
            completion(result)
        }
    }
}

/// Synchronous version for use when building full diagnostic report (call from background queue).
func runBrowserHealthScriptSync() -> String {
    runScriptSync()
}

private func runScriptSync() -> String {
    guard let scriptURL = Bundle.main.url(forResource: "browser_health_check", withExtension: "sh")
        ?? Bundle.main.url(forResource: "browser_health_check", withExtension: nil, subdirectory: nil)
        ?? findScriptInBundle() else {
        return "Error: browser_health_check.sh not found in app bundle. Add it to the target’s Copy Bundle Resources."
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [scriptURL.path]
    process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return "Error running script: \(error.localizedDescription)"
    }

    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    let out = String(data: outData, encoding: .utf8) ?? ""
    let err = String(data: errData, encoding: .utf8) ?? ""
    let combined = [out, err].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    return combined.isEmpty ? "(No output)" : combined
}


/// Fallback: look for script in bundle Resources directory by name.
private func findScriptInBundle() -> URL? {
    guard let resourceURL = Bundle.main.resourceURL else { return nil }
    let target = resourceURL.appendingPathComponent("browser_health_check.sh")
    if (try? target.checkResourceIsReachable()) == true { return target }
    return nil
}

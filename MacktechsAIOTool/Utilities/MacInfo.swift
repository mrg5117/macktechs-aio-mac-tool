//
//  MacInfo.swift
//  Macktechs AIO Mac Tool
//
//  Hardware info: model, CPU, memory, disk. Uses sysctl, ProcessInfo, FileManager.
//

import Foundation
import Darwin

struct MacInfo: Codable {
    let modelIdentifier: String
    let marketingName: String?
    let cpu: String
    let memoryGB: Int
    let totalDiskGB: Int
    let freeDiskGB: Int
}

private let modelNameMap: [String: String] = [
    "MacBookPro18,1": "MacBook Pro 14\" (M1 Pro, 2021)",
    "MacBookPro18,2": "MacBook Pro 14\" (M1 Max, 2021)",
    "MacBookPro18,3": "MacBook Pro 16\" (M1 Pro, 2021)",
    "MacBookPro18,4": "MacBook Pro 16\" (M1 Max, 2021)",
    "MacBookPro19,1": "MacBook Pro 14\" (M2 Pro/Max, 2023)",
    "MacBookPro19,2": "MacBook Pro 14\" (M2 Pro/Max, 2023)",
    "Mac14,2": "MacBook Pro 14\" (M2 Pro/Max, 2023)",
    "Mac14,7": "MacBook Pro 14\" (M3 Pro/Max, 2023)",
    "Mac15,3": "MacBook Pro 14\" (M3 Pro/Max, 2024)",
    "Mac15,4": "MacBook Pro 14\" (M4, 2024)",
    "iMac21,1": "iMac 24\" (M1, 2021)",
    "MacStudio1,1": "Mac Studio (M1 Max/Ultra, 2022)",
    "Mac14,13": "Mac Studio (M2 Max/Ultra, 2023)",
    "Macmini9,1": "Mac mini (M1, 2020)",
    "Mac14,3": "Mac mini (M2/M2 Pro, 2023)",
]

func getMacInfo() -> MacInfo {
    let modelId = getSysctlString("hw.model") ?? "Unknown"
    let cpu: String = {
        if let brand = getSysctlString("machdep.cpu.brand_string"), !brand.isEmpty {
            return brand.trimmingCharacters(in: .whitespaces)
        }
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Unknown"
        #endif
    }()
    let memBytes = ProcessInfo.processInfo.physicalMemory
    let memoryGB = Int(memBytes / (1024 * 1024 * 1024))
    let (totalGB, freeGB) = getRootVolumeSpace()
    let marketing = modelNameMap[modelId]

    return MacInfo(
        modelIdentifier: modelId,
        marketingName: marketing,
        cpu: cpu,
        memoryGB: memoryGB,
        totalDiskGB: totalGB,
        freeDiskGB: freeGB
    )
}

private func getSysctlString(_ name: String) -> String? {
    name.withCString { cName in
        var size = 0
        if sysctlbyname(cName, nil, &size, nil, 0) != 0 { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        if sysctlbyname(cName, &buffer, &size, nil, 0) != 0 { return nil }
        return String(utf8String: buffer)
    }
}

private func getRootVolumeSpace() -> (totalGB: Int, freeGB: Int) {
    let root = URL(fileURLWithPath: "/")
    do {
        let values = try root.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        let total = values.volumeTotalCapacity ?? 0
        let free = values.volumeAvailableCapacity ?? 0
        return (total / (1024 * 1024 * 1024), free / (1024 * 1024 * 1024))
    } catch {
        return (0, 0)
    }
}

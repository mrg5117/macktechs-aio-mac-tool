//
//  BatteryInfo.swift
//  Macktechs AIO Tool
//
//  Battery cycles and health via IOKit power source APIs.
//

import Foundation
import IOKit.ps

struct BatteryInfo: Codable {
    let cycleCount: Int?
    let designCapacity: Int?
    let maxCapacity: Int?
    /// Health percentage (maxCapacity / designCapacity * 100), nil if unavailable.
    let healthPercent: Int?
}

func getBatteryInfo() -> BatteryInfo {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() as CFTypeRef?,
          let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
          let source = list.first else {
        return BatteryInfo(cycleCount: nil, designCapacity: nil, maxCapacity: nil, healthPercent: nil)
    }

    guard let desc = IOPSGetPowerSourceDescription(info, source) as? [String: Any] else {
        return BatteryInfo(cycleCount: nil, designCapacity: nil, maxCapacity: nil, healthPercent: nil)
    }

    let cycles = (desc["Cycle Count"] as? NSNumber)?.intValue
    let design = (desc["Design Capacity"] as? NSNumber)?.intValue
    let maxCap = (desc["Max Capacity"] as? NSNumber)?.intValue

    var health: Int? = nil
    if let d = design, let m = maxCap, d > 0 {
        health = Int((Double(m) / Double(d)) * 100)
    }

    return BatteryInfo(
        cycleCount: cycles.map { Int($0) },
        designCapacity: design.map { Int($0) },
        maxCapacity: maxCap.map { Int($0) },
        healthPercent: health
    )
}

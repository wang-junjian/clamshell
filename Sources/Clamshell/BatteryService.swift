import Foundation
import IOKit.ps

struct BatterySnapshot: Equatable {
    var level: Int = 100
    var onAC: Bool = true
    var charging: Bool = false
    var hasBattery: Bool = false
}

/// 电池与供电状态。台式机（无电池）统一按"已接电源、100%"处理。
enum BatteryService {

    static func snapshot() -> BatterySnapshot {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return BatterySnapshot()
        }

        for source in sources {
            guard let raw = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue(),
                  let info = raw as? [String: Any]
            else { continue }

            guard let type = info[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType
            else { continue }

            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let state = info[kIOPSPowerSourceStateKey] as? String
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false

            let level = maximum > 0
                ? Int((Double(current) / Double(maximum) * 100).rounded())
                : 0

            return BatterySnapshot(
                level: max(0, min(100, level)),
                onAC: state == kIOPSACPowerValue,
                charging: charging,
                hasBattery: true
            )
        }

        return BatterySnapshot()
    }
}

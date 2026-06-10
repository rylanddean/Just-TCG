import Foundation

enum DevicePerformance {
    static let liteModeDefaultsKey = "home_lite_mode"

    static var isLowPower: Bool {
        ProcessInfo.processInfo.physicalMemory <= 3_500_000_000
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [liteModeDefaultsKey: isLowPower])
    }
}

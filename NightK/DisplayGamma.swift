import CoreGraphics
import Foundation

/// The NightK output uses the public display gamma LUT API exclusively.
/// macOS 27.2 on M5 Pro can accept an LUT without displaying it. Success below
/// means CoreGraphics accepted the request, not that hardware applied it.
enum DisplayGamma {
    @discardableResult
    static func applyTemperature(kelvin: Int) -> Bool {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            NSLog("NightK: cannot enumerate active displays")
            return false
        }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            NSLog("NightK: display enumeration failed")
            return false
        }
        var allAccepted = true
        for display in displays.prefix(Int(displayCount)) {
            // The affected M5 Pro LCD reports 1024 entries. The old fixed 256
            // sample table may be suboptimal; use the actual advertised capacity.
            let capacity = Int(CGDisplayGammaTableCapacity(display))
            guard let tables = GammaTransfer.make(kelvin: kelvin, count: capacity) else {
                NSLog("NightK: display %u has unsupported gamma capacity %ld", display, capacity)
                allAccepted = false
                continue
            }
            let result = tables.red.withUnsafeBufferPointer { r in
                tables.green.withUnsafeBufferPointer { g in
                    tables.blue.withUnsafeBufferPointer { b in
                        CGSetDisplayTransferByTable(display, UInt32(capacity), r.baseAddress, g.baseAddress, b.baseAddress)
                    }
                }
            }
            if result != .success {
                NSLog("NightK: display %u gamma API rejected: %d", display, result.rawValue)
                allAccepted = false
            }
        }
        return allAccepted
    }

    static func restore() {
        CGDisplayRestoreColorSyncSettings()
    }
}

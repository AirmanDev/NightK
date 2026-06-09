import Foundation
import CoreGraphics

enum DisplayGamma {
    private static let tableSize = 256

    static func applyTemperature(kelvin: Int) {
        let safeKelvin = kelvin.clamped(to: Temperature.range)
        let multipliers = rgbMultipliers(forKelvin: safeKelvin)

        var red = [CGGammaValue]()
        var green = [CGGammaValue]()
        var blue = [CGGammaValue]()

        red.reserveCapacity(tableSize)
        green.reserveCapacity(tableSize)
        blue.reserveCapacity(tableSize)

        for index in 0..<tableSize {
            let input = Float(index) / Float(tableSize - 1)

            red.append(CGGammaValue((input * multipliers.red).clamped(to: 0...1)))
            green.append(CGGammaValue((input * multipliers.green).clamped(to: 0...1)))
            blue.append(CGGammaValue((input * multipliers.blue).clamped(to: 0...1)))
        }

        for display in activeDisplays() {
            applyTables(to: display, red: red, green: green, blue: blue)
        }
    }

    static func restore() {
        CGDisplayRestoreColorSyncSettings()
    }

    private static func applyTables(
        to display: CGDirectDisplayID,
        red: [CGGammaValue],
        green: [CGGammaValue],
        blue: [CGGammaValue]
    ) {
        red.withUnsafeBufferPointer { redPointer in
            green.withUnsafeBufferPointer { greenPointer in
                blue.withUnsafeBufferPointer { bluePointer in
                    guard
                        let redBase = redPointer.baseAddress,
                        let greenBase = greenPointer.baseAddress,
                        let blueBase = bluePointer.baseAddress
                    else {
                        return
                    }

                    _ = CGSetDisplayTransferByTable(
                        display,
                        UInt32(tableSize),
                        redBase,
                        greenBase,
                        blueBase
                    )
                }
            }
        }
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0

        let countError = CGGetActiveDisplayList(0, nil, &displayCount)

        guard countError == .success, displayCount > 0 else {
            return []
        }

        var displays = Array<CGDirectDisplayID>(repeating: 0, count: Int(displayCount))
        let listError = CGGetActiveDisplayList(displayCount, &displays, &displayCount)

        guard listError == .success else {
            return []
        }

        return Array(displays.prefix(Int(displayCount)))
    }

    /// Tanner Helland's black-body approximation; valid for 1000K–40000K.
    private static func rgbMultipliers(forKelvin kelvin: Int) -> (red: Float, green: Float, blue: Float) {
        let temperature = Float(kelvin.clamped(to: 1000...40000)) / 100.0

        let red: Float
        let green: Float
        let blue: Float

        if temperature <= 66 {
            red = 1.0
            green = (0.3900815787690196 * log(temperature) - 0.6318414437886275).clamped(to: 0...1)
        } else {
            red = (1.292936186062745 * pow(temperature - 60, -0.1332047592)).clamped(to: 0...1)
            green = (1.129890860895294 * pow(temperature - 60, -0.0755148492)).clamped(to: 0...1)
        }

        if temperature >= 66 {
            blue = 1.0
        } else if temperature <= 19 {
            blue = 0.0
        } else {
            blue = (0.5432067891101961 * log(temperature - 10) - 1.19625408914).clamped(to: 0...1)
        }

        return (red, green, blue)
    }
}
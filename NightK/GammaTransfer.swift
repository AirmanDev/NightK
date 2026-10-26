import CoreGraphics
import Foundation

/// Build a device-resolution gamma LUT. This is true CoreGraphics gamma, not a
/// WindowServer tint overlay or an ICC profile replacement.
struct GammaTransfer {
    let red: [CGGammaValue]
    let green: [CGGammaValue]
    let blue: [CGGammaValue]

    static func make(kelvin: Int, count: Int) -> GammaTransfer? {
        guard (2...4096).contains(count) else { return nil }
        let scale = channelScale(kelvin: kelvin)
        let denominator = Float(count - 1)
        var red = [CGGammaValue](), green = [CGGammaValue](), blue = [CGGammaValue]()
        red.reserveCapacity(count)
        green.reserveCapacity(count)
        blue.reserveCapacity(count)
        for index in 0..<count {
            let level = Float(index) / denominator
            red.append((level * scale.red).clamped(to: 0...1))
            green.append((level * scale.green).clamped(to: 0...1))
            blue.append((level * scale.blue).clamped(to: 0...1))
        }
        return GammaTransfer(red: red, green: green, blue: blue)
    }

    /// Tanner Helland's approximation. The input range is bounded by Support.swift.
    private static func channelScale(kelvin: Int) -> (red: Float, green: Float, blue: Float) {
        let temperature = Float(kelvin.clamped(to: Temperature.range)) / 100.0
        let red: Float
        let green: Float
        let blue: Float
        if temperature <= 66 {
            red = 1
            green = (0.3900815787690196 * log(temperature) - 0.6318414437886275).clamped(to: 0...1)
        } else {
            red = (1.292936186062745 * pow(temperature - 60, -0.1332047592)).clamped(to: 0...1)
            green = (1.129890860895294 * pow(temperature - 60, -0.0755148492)).clamped(to: 0...1)
        }
        if temperature >= 66 { blue = 1 }
        else if temperature <= 19 { blue = 0 }
        else { blue = (0.5432067891101961 * log(temperature - 10) - 1.19625408914).clamped(to: 0...1) }
        return (red,green,blue)
    }
}

import Foundation
import Darwin

/// A compatibility compositor is needed where the display driver stores but ignores gamma LUTs.
enum DisplayMethod: String, CaseIterable, Identifiable {
    case automatic
    case gamma
    case compatibility

    var id: String { rawValue }

    func title(isHungarian: Bool) -> String {
        switch (self, isHungarian) {
        case (.automatic, true): "Automatikus"
        case (.automatic, false): "Automatic"
        case (.gamma, true): "Gamma"
        case (.gamma, false): "Gamma"
        case (.compatibility, true): "Kompatibilis"
        case (.compatibility, false): "Compatible"
        }
    }
}

enum DisplayCompatibility {
    /// Explicitly confirmed on this M5 Pro machine. Do not degrade other Macs by default.
    static func resolvedMethod(
        _ preference: DisplayMethod,
        hardwareModel: String,
        osVersion: OperatingSystemVersion
    ) -> DisplayMethod {
        guard preference == .automatic else { return preference }
        if hardwareModel == "Mac17,8", osVersion.majorVersion == 27, osVersion.minorVersion == 2 {
            return .compatibility
        }
        return .gamma
    }

    static var hardwareModel: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 1 else { return "" }
        var chars = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &chars, &size, nil, 0) == 0 else { return "" }
        return String(cString: chars)
    }

    /// A translucent amber surface is a visual approximation, not a true per-pixel
    /// white-point conversion. Never claim this is equivalent to a calibrated LUT.
    static func overlayOpacity(kelvin: Int) -> CGFloat {
        let temperature = Double(kelvin.clamped(to: Temperature.range))
        let warmth = (6500.0 - temperature) / 5500.0
        return CGFloat(warmth * 0.30)
    }
}

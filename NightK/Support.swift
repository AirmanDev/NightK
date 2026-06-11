import Foundation

// MARK: - Shared utilities

extension Comparable {
    /// Returns the value constrained to the given closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - App configuration

/// Single source of truth for the supported display colour temperature.
enum Temperature {
    /// Range exposed in the UI and enforced before applying gamma, in kelvin.
    static let range: ClosedRange<Int> = 1000...6500

    /// Slider increment, in kelvin.
    static let step = 50

    /// Value used on first launch, in kelvin.
    static let `default` = 1500
}

/// Default activation window used until the user changes it.
enum DefaultSchedule {
    static let startHour = 20
    static let startMinute = 0
    static let endHour = 7
    static let endMinute = 0
}

/// Gradual fade-in / fade-out behaviour at the edges of the active window.
enum Transition {
    /// Length of the ramp that eases the temperature in and out, in minutes.
    static let rampMinutes = 60

    /// How often the applied temperature is refreshed while ramping, in seconds.
    static let tickInterval: TimeInterval = 30
}

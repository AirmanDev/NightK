import Foundation
import CoreGraphics
import AppKit
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case hungarian = "hu"
    case english = "en"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .hungarian:
            return "Magyar"
        case .english:
            return "English"
        }
    }

    var text: NightKText {
        switch self {
        case .hungarian:
            return .hungarian
        case .english:
            return .english
        }
    }
}

struct NightKText {
    let subtitle: String
    let enabled: String
    let gradualTransition: String
    let gradualTransitionHint: String
    let launchAtLogin: String
    let language: String
    let temperature: String
    let temperatureHint: String
    let schedule: String
    let start: String
    let end: String
    let scheduleHint: String
    let active: String
    let inactive: String
    let reset: String
    let quit: String

    static let hungarian = NightKText(
        subtitle: "Fix időzítésű kijelzőmelegítés",
        enabled: "NightK bekapcsolva",
        gradualTransition: "Fokozatos átmenet",
        gradualTransitionHint: "Az időszak elején egy óra alatt erősödik fel, a végén ugyanennyi alatt cseng le.",
        launchAtLogin: "Indítás bejelentkezéskor",
        language: "Nyelv",
        temperature: "Hőmérséklet",
        temperatureHint: "Alacsonyabb érték = melegebb, narancsosabb kép.",
        schedule: "Időzítés",
        start: "Kezdés",
        end: "Vége",
        scheduleHint: "Éjfélen átnyúló időszakot is kezel.",
        active: "Aktív",
        inactive: "Inaktív",
        reset: "Reset",
        quit: "Kilépés"
    )

    static let english = NightKText(
        subtitle: "Fixed schedule display warming",
        enabled: "NightK enabled",
        gradualTransition: "Gradual transition",
        gradualTransitionHint: "Fades in over the first hour and back out over the last.",
        launchAtLogin: "Launch at login",
        language: "Language",
        temperature: "Temperature",
        temperatureHint: "Lower value = warmer, more orange display.",
        schedule: "Schedule",
        start: "Start",
        end: "End",
        scheduleHint: "Overnight schedules are supported.",
        active: "Active",
        inactive: "Inactive",
        reset: "Reset",
        quit: "Quit"
    )
}

@MainActor
final class NightKController: ObservableObject {
    static let shared = NightKController()

    @Published private(set) var isCurrentlyActive: Bool = false

    // Source of truth is the system (SMAppService), not UserDefaults.
    @Published private(set) var launchAtLogin: Bool = LoginItem.isEnabled

    @Published var isEnabled: Bool {
        didSet {
            save()
            scheduleNextTransition()
            applyDebounced()
        }
    }

    @Published var gradualTransitionEnabled: Bool {
        didSet {
            save()
            scheduleNextTransition()
            applyDebounced()
        }
    }

    @Published var temperatureKelvin: Int {
        didSet {
            save()
            applyDebounced()
        }
    }

    @Published var startTime: Date {
        didSet {
            save()
            scheduleNextTransition()
            applyDebounced()
        }
    }

    @Published var endTime: Date {
        didSet {
            save()
            scheduleNextTransition()
            applyDebounced()
        }
    }

    @Published var language: AppLanguage {
        didSet {
            save()
        }
    }

    private var transitionTimer: Timer?
    private var debounceWorkItem: DispatchWorkItem?
    private var hasStarted = false
    private var didRegisterDisplayCallback = false

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "NightK.isEnabled"
        static let gradualTransitionEnabled = "NightK.gradualTransitionEnabled"
        static let temperatureKelvin = "NightK.temperatureKelvin"
        static let startHour = "NightK.startHour"
        static let startMinute = "NightK.startMinute"
        static let endHour = "NightK.endHour"
        static let endMinute = "NightK.endMinute"
        static let language = "NightK.language"
    }

    private init() {
        let savedTemperature = defaults.integer(forKey: Keys.temperatureKelvin)
        let initialTemperature = savedTemperature == 0
            ? Temperature.default
            : savedTemperature.clamped(to: Temperature.range)

        let initialEnabled: Bool
        if defaults.object(forKey: Keys.isEnabled) == nil {
            initialEnabled = true
        } else {
            initialEnabled = defaults.bool(forKey: Keys.isEnabled)
        }

        let savedLanguageCode = defaults.string(forKey: Keys.language) ?? AppLanguage.hungarian.rawValue
        let initialLanguage = AppLanguage(rawValue: savedLanguageCode) ?? .hungarian

        let startHour = defaults.object(forKey: Keys.startHour) == nil ? DefaultSchedule.startHour : defaults.integer(forKey: Keys.startHour)
        let startMinute = defaults.object(forKey: Keys.startMinute) == nil ? DefaultSchedule.startMinute : defaults.integer(forKey: Keys.startMinute)

        let endHour = defaults.object(forKey: Keys.endHour) == nil ? DefaultSchedule.endHour : defaults.integer(forKey: Keys.endHour)
        let endMinute = defaults.object(forKey: Keys.endMinute) == nil ? DefaultSchedule.endMinute : defaults.integer(forKey: Keys.endMinute)

        self.temperatureKelvin = initialTemperature
        self.isEnabled = initialEnabled
        self.gradualTransitionEnabled = defaults.bool(forKey: Keys.gradualTransitionEnabled)
        self.language = initialLanguage
        self.startTime = Self.dateForTime(hour: startHour, minute: startMinute)
        self.endTime = Self.dateForTime(hour: endHour, minute: endMinute)
    }

    func start() {
        guard !hasStarted else { return }

        hasStarted = true

        observeWake()
        registerDisplayChangeCallback()

        scheduleNextTransition()
        applyNow()
    }

    // Setters exist for values that must be clamped or normalized before
    // storage; they also drop no-op updates so the UI can drive them
    // continuously without triggering redundant work. Values needing no
    // transformation (isEnabled, language) are bound directly in the view.

    func setTemperatureKelvin(_ value: Int) {
        let safeValue = value.clamped(to: Temperature.range)

        guard temperatureKelvin != safeValue else { return }

        temperatureKelvin = safeValue
    }

    func setStartTime(_ value: Date) {
        let normalized = Self.normalizedTimeDate(value)

        guard !Self.sameHourAndMinute(startTime, normalized) else { return }

        startTime = normalized
    }

    func setEndTime(_ value: Date) {
        let normalized = Self.normalizedTimeDate(value)

        guard !Self.sameHourAndMinute(endTime, normalized) else { return }

        endTime = normalized
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if try LoginItem.setEnabled(enabled) {
                LoginItem.openSystemSettings()
            }
        } catch {
            // Registration failed; the status read below reflects reality.
        }

        launchAtLogin = LoginItem.isEnabled
    }

    /// Re-reads the system state; call when the UI appears so changes made in
    /// System Settings are reflected.
    func refreshLaunchAtLogin() {
        launchAtLogin = LoginItem.isEnabled
    }

    func applyNow() {
        let temperature = effectiveTemperature(at: Date())

        isCurrentlyActive = temperature != nil

        if let temperature {
            DisplayGamma.applyTemperature(kelvin: temperature)
        } else {
            DisplayGamma.restore()
        }
    }

    func restoreDisplays() {
        DisplayGamma.restore()
        isCurrentlyActive = false
    }

    private func applyDebounced() {
        debounceWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            // asyncAfter on .main always runs on the main actor's executor.
            MainActor.assumeIsolated {
                self?.applyNow()
            }
        }

        debounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: item)
    }

    private func save() {
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(gradualTransitionEnabled, forKey: Keys.gradualTransitionEnabled)
        defaults.set(temperatureKelvin, forKey: Keys.temperatureKelvin)
        defaults.set(language.rawValue, forKey: Keys.language)

        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        defaults.set(startComponents.hour ?? DefaultSchedule.startHour, forKey: Keys.startHour)
        defaults.set(startComponents.minute ?? DefaultSchedule.startMinute, forKey: Keys.startMinute)

        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        defaults.set(endComponents.hour ?? DefaultSchedule.endHour, forKey: Keys.endHour)
        defaults.set(endComponents.minute ?? DefaultSchedule.endMinute, forKey: Keys.endMinute)
    }

    private func scheduleNextTransition() {
        transitionTimer?.invalidate()
        transitionTimer = nil

        guard hasStarted else { return }

        let timer = Timer(
            fireAt: nextEvaluationDate(after: Date()),
            interval: 0,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: false
        )

        transitionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func timerFired() {
        applyNow()
        scheduleNextTransition()
    }

    // The wake observer and the display-reconfiguration callback are
    // registered once and live for the whole process: `shared` is never
    // deallocated, so there is nothing to tear down.
    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delivered on .main, i.e. the main actor's executor.
            MainActor.assumeIsolated {
                self?.applyNow()
                self?.scheduleNextTransition()
            }
        }
    }

    private func registerDisplayChangeCallback() {
        guard !didRegisterDisplayCallback else { return }

        didRegisterDisplayCallback = true

        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        CGDisplayRegisterReconfigurationCallback({ _, _, userInfo in
            guard let userInfo else { return }

            let controller = Unmanaged<NightKController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                MainActor.assumeIsolated {
                    controller.applyNow()
                }
            }
        }, pointer)
    }

    private func isWithinActiveWindow(_ date: Date) -> Bool {
        let calendar = Calendar.current

        let nowMinutes = Self.minutesSinceMidnight(for: date, calendar: calendar)
        let startMinutes = Self.minutesSinceMidnight(for: startTime, calendar: calendar)
        let endMinutes = Self.minutesSinceMidnight(for: endTime, calendar: calendar)

        if startMinutes == endMinutes {
            return true
        }

        if startMinutes < endMinutes {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        }

        return nowMinutes >= startMinutes || nowMinutes < endMinutes
    }

    /// The colour temperature to apply at `date`, or `nil` when the display
    /// should be left at its native profile. With gradual transitions on, the
    /// value is interpolated between neutral and the configured target so the
    /// warming eases in at the start of the window and back out at the end.
    private func effectiveTemperature(at date: Date) -> Int? {
        guard isEnabled, isWithinActiveWindow(date) else { return nil }

        guard gradualTransitionEnabled else { return temperatureKelvin }

        let neutral = Double(Temperature.range.upperBound)
        let target = Double(temperatureKelvin)
        let value = neutral + (target - neutral) * warmthProgress(at: date)

        return Int(value.rounded()).clamped(to: Temperature.range)
    }

    /// How far the warming has ramped at `date`, from 0 (neutral) to 1 (full
    /// target). Rises over the first hour of the window and falls over the last;
    /// for windows shorter than two hours the two ramps simply meet partway.
    private func warmthProgress(at date: Date) -> Double {
        let calendar = Calendar.current
        let start = Self.minutesSinceMidnight(for: startTime, calendar: calendar)
        let end = Self.minutesSinceMidnight(for: endTime, calendar: calendar)
        let now = Self.minutesSinceMidnight(for: date, calendar: calendar)

        let total = Double(Self.windowLength(fromStart: start, toEnd: end))
        let sinceStart = Double(Self.minutesElapsed(fromStart: start, to: now))
        let ramp = Double(Transition.rampMinutes)

        let rampUp = (sinceStart / ramp).clamped(to: 0...1)
        let rampDown = ((total - sinceStart) / ramp).clamped(to: 0...1)

        return Swift.min(rampUp, rampDown)
    }

    /// Whether the temperature is actively changing at `date`, i.e. we are
    /// inside one of the fade ramps rather than holding at the target or off.
    private func isWithinRamp(at date: Date) -> Bool {
        guard gradualTransitionEnabled, isEnabled, isWithinActiveWindow(date) else {
            return false
        }

        let calendar = Calendar.current
        let start = Self.minutesSinceMidnight(for: startTime, calendar: calendar)
        let end = Self.minutesSinceMidnight(for: endTime, calendar: calendar)
        let now = Self.minutesSinceMidnight(for: date, calendar: calendar)

        let total = Self.windowLength(fromStart: start, toEnd: end)
        let sinceStart = Self.minutesElapsed(fromStart: start, to: now)
        let ramp = Transition.rampMinutes

        // Too short to ever reach the target: the whole window is one ramp.
        if total <= 2 * ramp { return true }

        return sinceStart < ramp || sinceStart >= total - ramp
    }

    /// The next instant the applied temperature should be re-evaluated: the
    /// upcoming window edges, plus a steady tick while a ramp is in progress.
    private func nextEvaluationDate(after date: Date) -> Date {
        var candidates = [
            nextDateMatchingTime(from: startTime, after: date),
            nextDateMatchingTime(from: endTime, after: date)
        ]

        if gradualTransitionEnabled {
            candidates.append(nextDateMatchingTime(from: shiftedTime(startTime, byMinutes: Transition.rampMinutes), after: date))
            candidates.append(nextDateMatchingTime(from: shiftedTime(endTime, byMinutes: -Transition.rampMinutes), after: date))

            if isWithinRamp(at: date) {
                candidates.append(date.addingTimeInterval(Transition.tickInterval))
            }
        }

        return candidates.min() ?? date.addingTimeInterval(Transition.tickInterval)
    }

    /// A clock time offset from `time` by `delta` minutes, wrapping at midnight.
    private func shiftedTime(_ time: Date, byMinutes delta: Int) -> Date {
        let base = Self.minutesSinceMidnight(for: time, calendar: Calendar.current)
        let shifted = (((base + delta) % 1440) + 1440) % 1440

        return Self.dateForTime(hour: shifted / 60, minute: shifted % 60)
    }

    private func nextDateMatchingTime(from time: Date, after date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        return calendar.nextDate(
            after: date,
            matching: DateComponents(hour: components.hour, minute: components.minute),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? date.addingTimeInterval(60)
    }

    private static func dateForTime(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour.clamped(to: 0...23)
        components.minute = minute.clamped(to: 0...59)
        components.second = 0

        return Calendar.current.date(from: components) ?? Date()
    }

    private static func normalizedTimeDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)

        return dateForTime(
            hour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0
        )
    }

    private static func sameHourAndMinute(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = Calendar.current
        let left = calendar.dateComponents([.hour, .minute], from: lhs)
        let right = calendar.dateComponents([.hour, .minute], from: rhs)

        return left.hour == right.hour && left.minute == right.minute
    }

    private static func minutesSinceMidnight(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)

        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    /// Length of the active window in minutes, handling overnight schedules.
    /// Matching `isWithinActiveWindow`, equal edges mean an always-on window.
    private static func windowLength(fromStart start: Int, toEnd end: Int) -> Int {
        if start == end { return 1440 }

        return start < end ? end - start : 1440 - start + end
    }

    /// Minutes elapsed from `start` to `now` on the clock, wrapping at midnight.
    private static func minutesElapsed(fromStart start: Int, to now: Int) -> Int {
        return (((now - start) % 1440) + 1440) % 1440
    }
}
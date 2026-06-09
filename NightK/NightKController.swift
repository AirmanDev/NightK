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
        let shouldBeActive = isEnabled && isWithinActiveWindow(Date())

        isCurrentlyActive = shouldBeActive

        if shouldBeActive {
            DisplayGamma.applyTemperature(kelvin: temperatureKelvin)
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

        let now = Date()
        let nextStart = nextDateMatchingTime(from: startTime, after: now)
        let nextEnd = nextDateMatchingTime(from: endTime, after: now)
        let nextFireDate = min(nextStart, nextEnd)

        let timer = Timer(
            fireAt: nextFireDate,
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
}
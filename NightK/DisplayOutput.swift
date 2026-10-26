import AppKit
import CoreGraphics

/// Owns the display output exclusively. Switching backends always tears down
/// the previous one first; on quit, there can be no retained overlay window.
@MainActor
final class DisplayOutput {
    private let overlay = WarmDisplayOverlay()
    private var currentMethod: DisplayMethod?

    @discardableResult
    func apply(kelvin: Int?, using method: DisplayMethod) -> Bool {
        let resolved = DisplayCompatibility.resolvedMethod(
            method,
            hardwareModel: DisplayCompatibility.hardwareModel,
            osVersion: ProcessInfo.processInfo.operatingSystemVersion
        )
        if currentMethod != resolved {
            overlay.remove()
            DisplayGamma.restore()
            currentMethod = resolved
        }

        guard let kelvin else {
            if resolved == .compatibility { overlay.remove() }
            else { DisplayGamma.restore() }
            return true
        }

        switch resolved {
        case .compatibility:
            return overlay.apply(kelvin: kelvin)
        case .gamma, .automatic:
            return DisplayGamma.applyTemperature(kelvin: kelvin)
        }
    }

    func restore() {
        overlay.remove()
        DisplayGamma.restore()
        currentMethod = nil
    }
}

/// Click-through, non-activating windows are shown on all desktops, including
/// full-screen Spaces. Uses standard AppKit; no private OS frameworks or access
/// to screen pixels, and no Screen Recording permission is necessary.
@MainActor
private final class WarmDisplayOverlay {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]

    func apply(kelvin: Int) -> Bool {
        let opacity = DisplayCompatibility.overlayOpacity(kelvin: kelvin)
        guard opacity > 0 else {
            remove()
            return true
        }
        let multipliers = DisplayGamma.rgbMultipliers(forKelvin: kelvin)
        let tint = NSColor(
            calibratedRed: CGFloat(multipliers.red) * 0.65,
            green: CGFloat(multipliers.green) * 0.70,
            blue: CGFloat(multipliers.blue) * 0.70,
            alpha: 1
        )
        var active: Set<CGDirectDisplayID> = []
        for screen in NSScreen.screens {
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else {
                continue
            }
            active.insert(id)
            let window: NSWindow
            if let existing = windows[id] {
                window = existing
            } else {
                window = NSPanel(
                    contentRect: screen.frame,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false,
                    screen: screen
                )
                window.level = .screenSaver
                window.ignoresMouseEvents = true
                window.isOpaque = false
                window.hasShadow = false
                window.hidesOnDeactivate = false
                window.isMovable = false
                window.animationBehavior = .none
                window.isReleasedWhenClosed = false
                window.collectionBehavior = [
                    .canJoinAllSpaces, .canJoinAllApplications,
                    .fullScreenAuxiliary, .stationary, .ignoresCycle
                ]
                windows[id] = window
            }
            window.setFrame(screen.frame, display: false)
            window.backgroundColor = tint
            window.alphaValue = opacity
            window.orderFrontRegardless()
        }
        for id in Set(windows.keys).subtracting(active) {
            windows.removeValue(forKey: id)?.close()
        }
        return !active.isEmpty
    }

    func remove() {
        for window in windows.values { window.close() }
        windows.removeAll()
    }
}

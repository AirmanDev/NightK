import SwiftUI
import AppKit

@main
struct NightKApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = NightKController.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(controller)
        } label: {
            Image("MenuBarIcon")
                .opacity(controller.isCurrentlyActive ? 1.0 : 0.55)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NightKController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NightKController.shared.restoreDisplays()
    }
}
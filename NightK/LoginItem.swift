import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for the "launch at login" toggle.
///
/// The system is the single source of truth for this setting: the user can also
/// toggle it from System Settings > General > Login Items, so the state is always
/// read back from `SMAppService`, never cached locally.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item.
    /// - Returns: `true` when the item was registered but still needs the user
    ///   to approve it in System Settings.
    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> Bool {
        let service = SMAppService.mainApp

        if enabled {
            if service.status != .enabled {
                try service.register()
            }
            return service.status == .requiresApproval
        } else {
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
            return false
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

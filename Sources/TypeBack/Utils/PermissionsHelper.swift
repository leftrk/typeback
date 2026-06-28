import AppKit

/// Helper for checking and requesting Accessibility permissions
enum PermissionsHelper {

    static func isAccessibilityEnabled() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermissionPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

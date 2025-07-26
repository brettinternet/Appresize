import Cocoa
import ServiceManagement


func showAccessibilityAlert() {
    let alert = NSAlert()
    alert.messageText = "Accessibility permissions required"
    alert.informativeText = """
    Appresize requires Accessibility permissions in order to be able to move and resize windows for you.

    You can grant Accessibility permissions in "System Preferences" → "Security & Privacy" → "Accessibility".

    """
    alert.addButton(withTitle: "Open System Preferences")
    switch alert.runModal() {
    case .alertFirstButtonReturn:
        NSWorkspace.shared.open(Links.securitySystemPreferences)
    default:
        break
    }
}


func showRestartPrompt() {
    let alert = NSAlert()
    alert.messageText = "Accessibility permissions granted!"
    alert.informativeText = """
    Appresize now has the required permissions to manage windows.
    
    Please restart the app to activate window management functionality.
    """
    alert.addButton(withTitle: "Restart App")
    alert.addButton(withTitle: "Later")
    switch alert.runModal() {
    case .alertFirstButtonReturn:
        restartApp()
    default:
        break
    }
}


func restartApp() {
    let bundlePath = Bundle.main.bundlePath
    log(.debug, "Attempting to restart app at: \(bundlePath)")
    
    // First try the standard approach (without -n since we're single-instance)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = [bundlePath]
    
    do {
        try task.run()
        log(.debug, "Restart command executed successfully")
        
        // Give the new instance time to start before terminating
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            log(.debug, "Terminating current instance")
            NSApp.terminate(nil)
        }
    } catch {
        log(.error, "Failed to restart app: \(error)")
        
        // Fallback: try with direct executable path
        attemptDirectExecutableRestart(bundlePath: bundlePath)
    }
}

private func attemptDirectExecutableRestart(bundlePath: String) {
    let executablePath = bundlePath + "/Contents/MacOS/Appresize"
    log(.debug, "Fallback: trying direct executable at \(executablePath)")
    
    let fallbackTask = Process()
    fallbackTask.executableURL = URL(fileURLWithPath: executablePath)
    
    do {
        try fallbackTask.run()
        log(.debug, "Fallback restart successful")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.terminate(nil)
        }
    } catch {
        log(.error, "Fallback restart also failed: \(error)")
        
        // Final fallback: show instructions to user
        showManualRestartInstructions()
    }
}

private func showManualRestartInstructions() {
    let alert = NSAlert()
    alert.messageText = "Please restart the app manually"
    alert.informativeText = """
    The automatic restart failed. Please manually quit and reopen Appresize to activate window management functionality.
    
    The app will now quit.
    """
    alert.addButton(withTitle: "OK")
    alert.runModal()
    NSApp.terminate(nil)
}


func isTrusted(prompt: Bool) -> Bool {
    let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
    let options = [prompt: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}


func appVersion(short: Bool = false) -> String {
    let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    if short {
        return shortVersion
    } else {
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(shortVersion) (\(bundleVersion))"
    }
}


// MARK: - Login Item Management

func setLaunchAtLogin(_ enabled: Bool) {
    if #available(macOS 13.0, *) {
        // Use modern ServiceManagement API for macOS 13+
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    } else {
        // Fallback for older macOS versions
        setLaunchAtLoginLegacy(enabled)
    }
}

func isLaunchAtLoginEnabled() -> Bool {
    if #available(macOS 13.0, *) {
        // Use modern ServiceManagement API for macOS 13+
        return SMAppService.mainApp.status == .enabled
    } else {
        // Fallback for older macOS versions
        return isLaunchAtLoginEnabledLegacy()
    }
}

@available(macOS, deprecated: 13.0)
private func setLaunchAtLoginLegacy(_ enabled: Bool) {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.finestructure.Appresize"
    
    if enabled {
        if !SMLoginItemSetEnabled(bundleIdentifier as CFString, true) {
            log(.error, "Failed to enable login item")
        }
    } else {
        if !SMLoginItemSetEnabled(bundleIdentifier as CFString, false) {
            log(.error, "Failed to disable login item")
        }
    }
}

@available(macOS, deprecated: 13.0)
private func isLaunchAtLoginEnabledLegacy() -> Bool {
    // For legacy versions, we'll check the UserDefaults since SMLoginItemSetEnabled
    // doesn't provide a way to query current state reliably
    return Current.defaults().bool(forKey: DefaultsKeys.launchAtLogin.rawValue)
}

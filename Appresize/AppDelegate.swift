import Cocoa
import os
import UserNotifications


func isLoginItemLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
    guard let event = event, event.eventID == kAEOpenApplication else {
        return false
    }
    return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    static func shouldPresentFirstLaunchSettings(isFirstLaunch: Bool, launchedAsLoginItem: Bool) -> Bool {
        isFirstLaunch && !launchedAsLoginItem
    }

    static func shouldPresentPermissionAlert(launchedAsLoginItem: Bool) -> Bool {
        !launchedAsLoginItem
    }

    static func statusIsActive(state: AppStateMachine.State, trackerIsActive: Bool, isTrusted: Bool) -> Bool {
        state == .activated && trackerIsActive && isTrusted
    }

    static func isUnitTestHost(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }

    @IBOutlet weak var statusMenu: NSMenu!
    var statusItem: NSStatusItem!
    @IBOutlet weak var enabledMenuItem: NSMenuItem!
    @IBOutlet weak var accessibilityStatusMenuItem: NSMenuItem!
    @IBOutlet weak var versionMenuItem: NSMenuItem!

    private var loadedPreferencesController: PreferencesController?
    lazy var preferencesController: PreferencesController = {
        let c = PreferencesController(windowNibName: "PreferencesController")
        loadedPreferencesController = c
        return c
    }()

    var stateMachine = AppStateMachine()
    private var permissionMonitorTimer: Timer?
    private var lastPermissionState = false
    private var launchedAsLoginItem = false
}


// App lifecycle
extension AppDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        launchedAsLoginItem = isLoginItemLaunch(NSAppleEventManager.shared().currentAppleEvent)
    }


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard !Self.isUnitTestHost() else { return }

        let isFirstLaunch = Date(forKey: .firstLaunched, defaults: Current.defaults()) == nil
        if isFirstLaunch {
            try? Current.date().save(forKey: .firstLaunched, defaults: Current.defaults())
        }

        // Sync login item state with UserDefaults
        let actualLoginState = isLaunchAtLoginEnabled()
        let savedLoginState = Current.defaults().bool(forKey: DefaultsKeys.launchAtLogin.rawValue)
        if actualLoginState != savedLoginState {
            Current.defaults().set(actualLoginState, forKey: DefaultsKeys.launchAtLogin.rawValue)
        }

        statusMenu?.delegate = self
        stateMachine.delegate = self
        // The first manual launch opens Settings as onboarding; keep that
        // presentation non-modal while preserving alerts for later activation.
        stateMachine.suppressActivationAlerts = launchedAsLoginItem || isFirstLaunch
        lastPermissionState = isTrusted(prompt: false)
        startPermissionMonitoring()
        stateMachine.state = .validatingState
        if isFirstLaunch {
            stateMachine.suppressActivationAlerts = launchedAsLoginItem
        }

        if Self.shouldPresentFirstLaunchSettings(isFirstLaunch: isFirstLaunch, launchedAsLoginItem: launchedAsLoginItem) {
            NSApp.activate(ignoringOtherApps: true)
            preferencesController.showWindow(nil)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        stopPermissionMonitoring()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Always show preferences when app is reopened
        NSApp.activate(ignoringOtherApps: true)
        preferencesController.showWindow(nil)
        return false
    }

    override func awakeFromNib() {
        registerDefaultPreferences()
        if Current.defaults().bool(forKey: DefaultsKeys.showMenuIcon.rawValue) {
            addStatusItemToMenubar()
        }
    }
}


extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        do {
            let hidden = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option
            versionMenuItem?.isHidden = !hidden
        }
        accessibilityStatusMenuItem?.isHidden = lastPermissionState
        accessibilityStatusMenuItem?.title = "⚠️ Accessibility permission required"
        updateStatusPresentation(trusted: lastPermissionState)
    }
}

// MARK:- Manage status item

extension AppDelegate {
    func addStatusItemToMenubar() {
        statusItem = {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem.menu = statusMenu
            statusItem.button?.image = NSImage(named: "MenuIcon")
            statusItem.button?.setAccessibilityLabel("Appresize status")
            return statusItem
        }()
        statusMenu?.autoenablesItems = false
        versionMenuItem?.title = "Version: \(appVersion())"
    }

    func removeStatusItemFromMenubar() {
        guard let statusItem = statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func updateStatusItemVisibility() {
        Current.defaults().bool(forKey: DefaultsKeys.showMenuIcon.rawValue)
            ? addStatusItemToMenubar()
            : removeStatusItemFromMenubar()
    }

    private func updateStatusPresentation(trusted: Bool) {
        let active = Self.statusIsActive(state: stateMachine.state, trackerIsActive: Tracker.isActive, isTrusted: trusted)
        enabledMenuItem?.state = active ? .on : .off
        enabledMenuItem?.title = "Enabled"
        enabledMenuItem?.setAccessibilityValue(active ? "On" : "Off")
        statusItem?.button?.alphaValue = active ? 1.0 : 0.45
        statusItem?.button?.setAccessibilityValue(
            trusted ? (active ? "Enabled" : "Paused") : "Accessibility permission required"
        )
    }

}


// MARK:- Permission Monitoring
extension AppDelegate {
    private func startPermissionMonitoring() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermissionChange()
        }
        permissionMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func stopPermissionMonitoring() {
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
    }
    
    private func checkPermissionChange() {
        let currentPermissionState = isTrusted(prompt: false)
        
        // Check if permissions were just granted (changed from false to true)
        if !lastPermissionState && currentPermissionState {
            if stateMachine.state == .deactivated {
                stateMachine.checkState()
            } else if stateMachine.state == .activated && !Tracker.isActive {
                stateMachine.state = .deactivated
                stateMachine.checkState()
            }
            if stateMachine.state != .activated && Self.shouldPresentPermissionAlert(launchedAsLoginItem: launchedAsLoginItem) {
                showRestartPrompt()
            }
        }
        // Check if permissions were just revoked (changed from true to false)
        else if lastPermissionState && !currentPermissionState {
            log(.error, "Accessibility permissions revoked - immediately deactivating to prevent system crashes")
            stateMachine.deactivate()
            if Self.shouldPresentPermissionAlert(launchedAsLoginItem: launchedAsLoginItem) {
                showPermissionRevokedAlert()
            }
        }
        
        lastPermissionState = currentPermissionState
        updateStatusPresentation(trusted: currentPermissionState)
        loadedPreferencesController?.updateAccessibilityStatus(trusted: currentPermissionState)
    }
}


// MARK:- IBActions
extension AppDelegate {
    @IBAction func enabledClicked(_ sender: NSMenuItem) {
        let previousAlertPolicy = stateMachine.suppressActivationAlerts
        let trusted = isTrusted(prompt: false)
        if !trusted {
            // This is an explicit user action, so it may use the normal
            // Accessibility permission flow even for a silent login launch.
            stateMachine.suppressActivationAlerts = false
        }
        stateMachine.toggleEnabled()
        stateMachine.suppressActivationAlerts = previousAlertPolicy
        lastPermissionState = trusted
        updateStatusPresentation(trusted: trusted)
    }

    @IBAction func accessibilityStatusClicked(_ sender: Any) {
        showAccessibilityAlert()
    }

    @IBAction func showPreferences(_ sender: Any) {
        NSApp.activate(ignoringOtherApps: true)
        preferencesController.showWindow(sender)
    }

    @IBAction func helpClicked(_ sender: Any) {
        NSWorkspace.shared.open(Links.appHelp)
    }

    @IBAction func reportIssueClicked(_ sender: Any) {
        NSWorkspace.shared.open(Links.appIssues)
    }

}


extension AppDelegate: DidTransitionDelegate {
    func didTransition(from: AppStateMachine.State, to: AppStateMachine.State) {
        updateStatusPresentation(trusted: lastPermissionState)
    }
}

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

    @IBOutlet weak var statusMenu: NSMenu!
    var statusItem: NSStatusItem!
    @IBOutlet weak var accessibilityStatusMenuItem: NSMenuItem!
    @IBOutlet weak var versionMenuItem: NSMenuItem!

    lazy var preferencesController: PreferencesController = {
        let c = PreferencesController(windowNibName: "PreferencesController")
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
        if Date(forKey: .firstLaunched, defaults: Current.defaults()) == nil {
            try? Current.date().save(forKey: .firstLaunched, defaults: Current.defaults())
        }

        // Sync login item state with UserDefaults
        let actualLoginState = isLaunchAtLoginEnabled()
        let savedLoginState = Current.defaults().bool(forKey: DefaultsKeys.launchAtLogin.rawValue)
        if actualLoginState != savedLoginState {
            Current.defaults().set(actualLoginState, forKey: DefaultsKeys.launchAtLogin.rawValue)
        }

        statusMenu?.delegate = self
        lastPermissionState = isTrusted(prompt: false)
        startPermissionMonitoring()
        stateMachine.state = .validatingState

        if !Current.defaults().bool(forKey: DefaultsKeys.showMenuIcon.rawValue),
           !launchedAsLoginItem {
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
        do {
            accessibilityStatusMenuItem?.isHidden = isTrusted(prompt: false)
        }
    }
}

// MARK:- Manage status item

extension AppDelegate {
    func addStatusItemToMenubar() {
        statusItem = {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem.menu = statusMenu
            statusItem.button?.image = NSImage(named: "MenuIcon")
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

}


// MARK:- Permission Monitoring
extension AppDelegate {
    private func startPermissionMonitoring() {
        permissionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermissionChange()
        }
    }
    
    private func stopPermissionMonitoring() {
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
    }
    
    private func checkPermissionChange() {
        let currentPermissionState = isTrusted(prompt: false)
        
        // Check if permissions were just granted (changed from false to true)
        if !lastPermissionState && currentPermissionState {
            stateMachine.checkState()
            if stateMachine.state != .activated {
                showRestartPrompt()
            }
        }
        // Check if permissions were just revoked (changed from true to false)
        else if lastPermissionState && !currentPermissionState {
            log(.error, "Accessibility permissions revoked - immediately deactivating to prevent system crashes")
            stateMachine.deactivate()
            showPermissionRevokedAlert()
        }
        
        lastPermissionState = currentPermissionState
    }
}


// MARK:- IBActions
extension AppDelegate {
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

}

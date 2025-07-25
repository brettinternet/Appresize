import Cocoa
import os
import UserNotifications


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
}


// App lifecycle
extension AppDelegate {
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
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        stopPermissionMonitoring()
    }

    override func awakeFromNib() {
        if Current.defaults().bool(forKey: DefaultsKeys.showMenuIcon.rawValue) {
            addStatusItemToMenubar()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            preferencesController.showWindow(nil)
            return
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
            showRestartPrompt()
            stopPermissionMonitoring() // Stop monitoring after showing prompt
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

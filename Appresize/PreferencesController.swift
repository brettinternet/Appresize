import Cocoa


protocol PreferencesControllerDelegate: AnyObject {
    func didRequestRegistrationController()
    func didRequestTipJarController()
}


class PreferencesController: NSWindowController {

    @IBOutlet weak var moveAlt: NSButton!
    @IBOutlet weak var moveCommand: NSButton!
    @IBOutlet weak var moveControl: NSButton!
    @IBOutlet weak var moveFn: NSButton!
    @IBOutlet weak var moveShift: NSButton!

    @IBOutlet weak var resizeAlt: NSButton!
    @IBOutlet weak var resizeCommand: NSButton!
    @IBOutlet weak var resizeControl: NSButton!
    @IBOutlet weak var resizeFn: NSButton!
    @IBOutlet weak var resizeShift: NSButton!

    @IBOutlet weak var resizeFromNearestCorner: NSButton!
    @IBOutlet weak var resizeInfoLabel: NSTextField!

    @IBOutlet weak var showMenuIcon: NSButton!
    @IBOutlet weak var launchAtLogin: NSButton!
    @IBOutlet weak var requireDragToActivate: NSButton!

    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var accessibilityStatusLabel: NSTextField!
    @IBOutlet weak var openSystemSettingsButton: NSButton!
    @IBOutlet weak var githubLink: NSTextField!
    
    private var permissionMonitorTimer: Timer?

    override func windowDidLoad() {
        super.windowDidLoad()
        updateAccessibilityStatus()
        updateCopy()
        setupGitHubLink()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        updateAccessibilityStatus()
        updateCopy()
        startPermissionMonitoring()
    }


    @IBAction func modifierClicked(_ sender: NSButton) {
        let moveButtons = [moveAlt, moveCommand, moveControl, moveFn, moveShift]
        let moveModifiers: [Modifiers<Move>] = [.alt, .command, .control, .fn, .shift]
        let resizeButtons = [resizeAlt, resizeCommand, resizeControl, resizeFn, resizeShift]
        let resizeModifiers: [Modifiers<Resize>] = [.alt, .command, .control, .fn, .shift]
        let modifierForButton = Dictionary(
            uniqueKeysWithValues: zip(moveButtons + resizeButtons,
                                      moveModifiers.map { $0.rawValue } + resizeModifiers.map { $0.rawValue } )
        )
        if let modifier = modifierForButton[sender] {
            if moveButtons.contains(sender) {
                let modifiers = Modifiers<Move>(forKey: .moveModifiers, defaults: Current.defaults())
                let m = Modifiers<Move>(rawValue: modifier)
                try? modifiers.toggle(m).save(forKey: .moveModifiers, defaults: Current.defaults())
            } else if resizeButtons.contains(sender) {
                let modifiers = Modifiers<Resize>(forKey: .resizeModifiers, defaults: Current.defaults())
                let m = Modifiers<Resize>(rawValue: modifier)
                try? modifiers.toggle(m).save(forKey: .resizeModifiers, defaults: Current.defaults())
            }
            Tracker.shared?.readModifiers()
        }
    }

    @IBAction func resizeFromNearestCornerClicked(_ sender: Any) {
        let value: NSNumber = {
            var v = Current.defaults().bool(forKey: DefaultsKeys.resizeFromNearestCorner.rawValue)
            v.toggle()
            return NSNumber(booleanLiteral: v)
        }()
        Current.defaults().set(value, forKey: DefaultsKeys.resizeFromNearestCorner.rawValue)
        updateCopy()
    }

    @IBAction func hideMenuIconClicked(_ sender: Any) {
        let value: NSNumber = {
            var v = Current.defaults().bool(forKey:
                DefaultsKeys.showMenuIcon.rawValue)
            v.toggle()
            return NSNumber(booleanLiteral: v)
        }()
        Current.defaults().set(value, forKey:
            DefaultsKeys.showMenuIcon.rawValue)
        updateCopy()
        (NSApp.delegate as? AppDelegate)?.updateStatusItemVisibility()
    }
    
    @IBAction func launchAtLoginClicked(_ sender: Any) {
        let value: NSNumber = {
            var v = Current.defaults().bool(forKey: DefaultsKeys.launchAtLogin.rawValue)
            v.toggle()
            return NSNumber(booleanLiteral: v)
        }()
        Current.defaults().set(value, forKey: DefaultsKeys.launchAtLogin.rawValue)
        setLaunchAtLogin(value.boolValue)
        updateCopy()
    }
    
    @IBAction func requireDragToActivateClicked(_ sender: Any) {
        let value: NSNumber = {
            var v = Current.defaults().bool(forKey: DefaultsKeys.requireDragToActivate.rawValue)
            v.toggle()
            return NSNumber(booleanLiteral: v)
        }()
        Current.defaults().set(value, forKey: DefaultsKeys.requireDragToActivate.rawValue)
        Tracker.shared?.readModifiers()  // Update the tracker with new setting
        updateCopy()
    }
    
    @IBAction func openSystemSettingsClicked(_ sender: Any) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func setupGitHubLink() {
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(githubLinkClicked(_:)))
        githubLink.addGestureRecognizer(clickGesture)
        
        // Add tracking area for cursor changes
        let trackingArea = NSTrackingArea(
            rect: githubLink.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["element": "githubLink"]
        )
        githubLink.addTrackingArea(trackingArea)
    }
    
    @objc private func githubLinkClicked(_ sender: Any) {
        let url = URL(string: "https://github.com/brettinternet/Appresize")!
        NSWorkspace.shared.open(url)
    }
    
    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let element = userInfo["element"] as? String,
           element == "githubLink" {
            NSCursor.pointingHand.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let element = userInfo["element"] as? String,
           element == "githubLink" {
            NSCursor.arrow.set()
        }
    }
}

extension PreferencesController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        stopPermissionMonitoring()
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        do {
            let prefs = Modifiers<Move>(forKey: .moveModifiers, defaults: Current.defaults())
            let buttons = [moveAlt, moveCommand, moveControl, moveFn, moveShift]
            let allModifiers: [Modifiers<Move>] = [.alt, .command, .control, .fn, .shift]
            let buttonForModifier = Dictionary(uniqueKeysWithValues: zip(allModifiers, buttons))
            for (modifier, button) in buttonForModifier {
                button?.state = prefs.contains(modifier) ? .on : .off
            }
        }

        do {
            let prefs = Modifiers<Resize>(forKey: .resizeModifiers, defaults: Current.defaults())
            let buttons = [resizeAlt, resizeCommand, resizeControl, resizeFn, resizeShift]
            let allModifiers: [Modifiers<Resize>] = [.alt, .command, .control, .fn, .shift]
            let buttonForModifier = Dictionary(uniqueKeysWithValues: zip(allModifiers, buttons))
            for (modifier, button) in buttonForModifier {
                button?.state = prefs.contains(modifier) ? .on : .off
            }
        }

        resizeFromNearestCorner?.state = Current.defaults().bool(forKey: DefaultsKeys.resizeFromNearestCorner.rawValue)
            ? .on : .off

        showMenuIcon?.state = Current.defaults().bool(forKey: DefaultsKeys.showMenuIcon.rawValue)
            ? .on : .off

        launchAtLogin?.state = Current.defaults().bool(forKey: DefaultsKeys.launchAtLogin.rawValue)
            ? .on : .off

        requireDragToActivate?.state = Current.defaults().bool(forKey: DefaultsKeys.requireDragToActivate.rawValue)
            ? .on : .off

        updateAccessibilityStatus()
        updateCopy()
    }

    func updateAccessibilityStatus() {
        let isEnabled = isTrusted(prompt: false)
        
        if isEnabled {
            accessibilityStatusLabel?.isHidden = true
            openSystemSettingsButton?.isHidden = true
        } else {
            accessibilityStatusLabel?.isHidden = false
            accessibilityStatusLabel?.stringValue = "⚠️ Accessibility permission is required"
            accessibilityStatusLabel?.textColor = NSColor.systemOrange
            openSystemSettingsButton?.isHidden = false
        }
    }
    
    func updateCopy() {
        resizeInfoLabel?.stringValue = Current.defaults().bool(forKey: DefaultsKeys.resizeFromNearestCorner.rawValue)
            ? "Resizing will act on the window corner nearest to the cursor."
            : "Resizing will act on the lower right corner of the window."

        versionLabel?.stringValue = appVersion(short: true)
    }
    
    private func startPermissionMonitoring() {
        // Stop any existing timer
        stopPermissionMonitoring()
        
        // Check accessibility permissions every 2 seconds while preferences window is open
        permissionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAccessibilityStatus()
        }
    }
    
    private func stopPermissionMonitoring() {
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
    }
}

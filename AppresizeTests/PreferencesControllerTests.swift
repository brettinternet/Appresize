import AppKit
import XCTest
@testable import Appresize

@MainActor
final class PreferencesControllerTests: XCTestCase {
    func testAccessibilityStatusOnlyReservesSpaceWhenPermissionIsMissing() throws {
        let controller = PreferencesController(windowNibName: "PreferencesController")
        controller.loadWindow()

        controller.updateAccessibilityStatus(trusted: false)
        XCTAssertEqual(controller.window?.contentView?.frame.size, NSSize(width: 390, height: 282))
        let expandedTopEdge = try XCTUnwrap(controller.window).frame.maxY
        XCTAssertFalse(controller.accessibilityStatusLabel.isHidden)
        XCTAssertFalse(controller.openSystemSettingsButton.isHidden)
        XCTAssertLessThanOrEqual(
            controller.openSystemSettingsButton.frame.maxY,
            controller.accessibilityStatusLabel.frame.minY
        )

        controller.updateAccessibilityStatus(trusted: true)
        XCTAssertEqual(controller.window?.contentView?.frame.size, NSSize(width: 390, height: 230))
        XCTAssertEqual(controller.window?.frame.maxY, expandedTopEdge)
        XCTAssertTrue(controller.accessibilityStatusLabel.isHidden)
        XCTAssertTrue(controller.openSystemSettingsButton.isHidden)
    }

    func testModifierClickUpdatesStoredShortcut() throws {
        let defaults = testUserDefaults()
        registerDefaultPreferences(in: defaults)
        try Modifiers<Move>([.control, .fn]).save(forKey: .moveModifiers, defaults: defaults)
        try Modifiers<Resize>([.shift, .fn]).save(forKey: .resizeModifiers, defaults: defaults)

        let originalDefaults = Current.defaults
        Current.defaults = { defaults }
        defer { Current.defaults = originalDefaults }

        let controller = PreferencesController()
        let moveButtons = (0..<5).map { _ in NSButton() }
        let resizeButtons = (0..<5).map { _ in NSButton() }
        let resizeInfoLabel = NSTextField(labelWithString: "")
        let conflictLabel = NSTextField(labelWithString: "")
        let versionLabel = NSTextField(labelWithString: "")

        controller.moveAlt = moveButtons[0]
        controller.moveCommand = moveButtons[1]
        controller.moveControl = moveButtons[2]
        controller.moveFn = moveButtons[3]
        controller.moveShift = moveButtons[4]
        controller.resizeAlt = resizeButtons[0]
        controller.resizeCommand = resizeButtons[1]
        controller.resizeControl = resizeButtons[2]
        controller.resizeFn = resizeButtons[3]
        controller.resizeShift = resizeButtons[4]
        controller.resizeInfoLabel = resizeInfoLabel
        controller.modifierConflictLabel = conflictLabel
        controller.versionLabel = versionLabel

        controller.updateModifierButtonStates()
        XCTAssertEqual(moveButtons.map(\.state), [.off, .off, .on, .on, .off])
        XCTAssertEqual(resizeButtons.map(\.state), [.off, .off, .off, .on, .on])

        controller.updateCopy()
        controller.modifierClicked(resizeButtons[4])

        let updated = Modifiers<Resize>(forKey: .resizeModifiers, defaults: defaults)
        XCTAssertEqual(updated, [.fn])
    }
}

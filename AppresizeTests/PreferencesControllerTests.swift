import AppKit
import XCTest
@testable import Appresize

@MainActor
final class PreferencesControllerTests: XCTestCase {
    func testModifierClickRefreshesShortcutCopy() throws {
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
        let quickStartLabel = NSTextField(labelWithString: "")
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
        controller.quickStartLabel = quickStartLabel
        controller.modifierConflictLabel = conflictLabel
        controller.versionLabel = versionLabel

        controller.updateModifierButtonStates()
        XCTAssertEqual(moveButtons.map(\.state), [.off, .off, .on, .on, .off])
        XCTAssertEqual(resizeButtons.map(\.state), [.off, .off, .off, .on, .on])

        controller.updateCopy()
        controller.modifierClicked(resizeButtons[4])

        XCTAssertEqual(
            quickStartLabel.stringValue,
            "Hold ⌃ fn and move the pointer to move a window.\nHold fn to resize it."
        )
    }
}

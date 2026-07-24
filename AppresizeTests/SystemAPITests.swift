import XCTest
import ApplicationServices
@testable import Appresize


final class SystemAPITests: XCTestCase {

    func testAccessibilityTrustOptionsUseRequestedBoolean() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

        let prompted = accessibilityTrustOptions(prompt: true) as NSDictionary
        XCTAssertEqual((prompted[key] as? NSNumber)?.boolValue, true)

        let silent = accessibilityTrustOptions(prompt: false) as NSDictionary
        XCTAssertEqual((silent[key] as? NSNumber)?.boolValue, false)
    }
}

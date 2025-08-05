import XCTest
@testable import Appresize

class WindowTilingTests: XCTestCase {
    
    func testGetTileZone() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // Test left edge
        let leftPoint = CGPoint(x: 30, y: 500)
        XCTAssertEqual(WindowTiling.getTileZone(for: leftPoint, in: screenFrame), .left)
        
        // Test right edge
        let rightPoint = CGPoint(x: 1890, y: 500)
        XCTAssertEqual(WindowTiling.getTileZone(for: rightPoint, in: screenFrame), .right)
        
        // Test top edge
        let topPoint = CGPoint(x: 500, y: 1050)
        XCTAssertEqual(WindowTiling.getTileZone(for: topPoint, in: screenFrame), .top)
        
        // Test bottom edge
        let bottomPoint = CGPoint(x: 500, y: 30)
        XCTAssertEqual(WindowTiling.getTileZone(for: bottomPoint, in: screenFrame), .bottom)
        
        // Test top-left corner
        let topLeftPoint = CGPoint(x: 30, y: 1050)
        XCTAssertEqual(WindowTiling.getTileZone(for: topLeftPoint, in: screenFrame), .topLeft)
        
        // Test center (no tiling)
        let centerPoint = CGPoint(x: 960, y: 540)
        XCTAssertEqual(WindowTiling.getTileZone(for: centerPoint, in: screenFrame), .none)
    }
    
    func testGetTargetFrame() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // Test left half
        let leftFrame = WindowTiling.getTargetFrame(for: .left, in: screenFrame)
        let expectedLeft = CGRect(x: 0, y: 0, width: 960, height: 1080)
        XCTAssertEqual(leftFrame, expectedLeft)
        
        // Test right half
        let rightFrame = WindowTiling.getTargetFrame(for: .right, in: screenFrame)
        let expectedRight = CGRect(x: 960, y: 0, width: 960, height: 1080)
        XCTAssertEqual(rightFrame, expectedRight)
        
        // Test top half
        let topFrame = WindowTiling.getTargetFrame(for: .top, in: screenFrame)
        let expectedTop = CGRect(x: 0, y: 540, width: 1920, height: 540)
        XCTAssertEqual(topFrame, expectedTop)
        
        // Test top-left quarter
        let topLeftFrame = WindowTiling.getTargetFrame(for: .topLeft, in: screenFrame)
        let expectedTopLeft = CGRect(x: 0, y: 540, width: 960, height: 540)
        XCTAssertEqual(topLeftFrame, expectedTopLeft)
    }
    
    func testGetScreenFrame() {
        // This test would require mocking NSScreen, so we'll just verify the method exists
        let point = CGPoint(x: 100, y: 100)
        let result = WindowTiling.getScreenFrame(containing: point)
        // In a real environment, this should return a screen frame or nil
        // In tests, it may return nil since there might not be screens available
    }
}
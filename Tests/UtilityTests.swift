import XCTest
@testable import MokuView

final class UtilityTests: XCTestCase {
    func testByteCountFormatter() {
        XCTAssertEqual(ByteCountFormatter.formattedSize(0), "0 KB")
        XCTAssertFalse(ByteCountFormatter.formattedSize(1024).isEmpty)
    }
    
    func testThrottleBox() {
        let throttle = ThrottleBox(interval: 0.1) // 100ms
        
        XCTAssertTrue(throttle.shouldUpdate()) // first time should be true
        XCTAssertFalse(throttle.shouldUpdate()) // immediately after should be false
        
        Thread.sleep(forTimeInterval: 0.11)
        
        XCTAssertTrue(throttle.shouldUpdate()) // after interval should be true
    }
    
    func testProgressAccumulator() {
        let acc = ProgressAccumulator()
        acc.add(bytes: 100, files: 1)
        acc.add(bytes: 200, files: 2)
        
        let snap = acc.snapshot()
        XCTAssertEqual(snap.bytes, 300)
        XCTAssertEqual(snap.files, 3)
        XCTAssertEqual(snap.dirs, 2)
    }
}

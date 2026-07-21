import XCTest

// flutter_bin is now a pure-Dart package with no macOS native code, so there is
// no plugin module to exercise here. The behaviour that this target used to
// test (Info.plist version/metadata reading) is now covered by the Dart tests
// in the package's `test/macos/` directory. This placeholder keeps the
// example's macOS test target valid without referencing the removed plugin.
class RunnerTests: XCTestCase {
  func testPlaceholder() {
    XCTAssertTrue(true)
  }
}

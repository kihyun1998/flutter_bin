import Cocoa
import FlutterMacOS
import XCTest

@testable import flutter_bin

// Exercises the macOS plugin through its public `handle(_:result:)` entry point,
// using a throwaway `.app` bundle with a known Info.plist as a deterministic
// fixture. Replaces the default template test, which called a `getPlatformVersion`
// method the plugin never implemented.
class RunnerTests: XCTestCase {

  // Builds a temporary `<tmp>/Fixture.app` whose Contents/Info.plist carries
  // known values, and returns the path to the `.app`.
  private func makeFixtureApp(version: String) -> String {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("flutter_bin_fixture_\(UUID().uuidString)")
    let contents = base.appendingPathComponent("Fixture.app/Contents")
    try! FileManager.default.createDirectory(
      at: contents, withIntermediateDirectories: true)

    let plist: [String: Any] = [
      "CFBundleShortVersionString": version,
      "CFBundleName": "Fixture Product",
      "CFBundleGetInfoString": "Fixture Description",
      "NSHumanReadableCopyright": "(c) 2026 Fixture",
      "CFBundleExecutable": "fixture",
    ]
    (plist as NSDictionary).write(
      to: contents.appendingPathComponent("Info.plist"), atomically: true)

    return contents.deletingLastPathComponent().path  // .../Fixture.app
  }

  // Invokes a method on a fresh plugin instance and returns the captured result.
  private func invoke(_ method: String, filePath: String) -> Any? {
    let plugin = FlutterBinPlugin()
    let call = FlutterMethodCall(
      methodName: method, arguments: ["filePath": filePath])
    var captured: Any?
    let done = expectation(description: "result delivered")
    plugin.handle(call) { result in
      captured = result
      done.fulfill()
    }
    waitForExpectations(timeout: 1)
    return captured
  }

  func testVersionOfKnownBundle() {
    let app = makeFixtureApp(version: "3.1.4")
    XCTAssertEqual(invoke("getBinaryFileVersion", filePath: app) as? String, "3.1.4")
  }

  func testMetadataOfKnownBundle() {
    let app = makeFixtureApp(version: "3.1.4")
    let metadata = invoke("getBinaryFileMetadata", filePath: app) as? [String: String]
    XCTAssertNotNil(metadata)
    XCTAssertEqual(metadata?["version"], "3.1.4")
    XCTAssertEqual(metadata?["productName"], "Fixture Product")
    XCTAssertEqual(metadata?["fileDescription"], "Fixture Description")
    XCTAssertEqual(metadata?["originalFilename"], "fixture")
    // companyName is not represented in a macOS Info.plist; always empty.
    XCTAssertEqual(metadata?["companyName"], "")
  }

  func testVersionOfMissingBundleIsNil() {
    XCTAssertNil(
      invoke("getBinaryFileVersion", filePath: "/no/such/path.app") as? String)
  }

  func testMissingFilePathArgumentIsError() {
    let plugin = FlutterBinPlugin()
    let call = FlutterMethodCall(methodName: "getBinaryFileVersion", arguments: [:])
    var captured: Any?
    let done = expectation(description: "result delivered")
    plugin.handle(call) { result in
      captured = result
      done.fulfill()
    }
    waitForExpectations(timeout: 1)
    XCTAssertTrue(captured is FlutterError)
  }
}

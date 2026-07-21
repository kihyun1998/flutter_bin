## 3.0.0

* **BREAKING**:
  * `flutter_bin` is now a **pure-Dart package**, not a Flutter plugin. It no
    longer depends on Flutter, `plugin_platform_interface`, or a method channel,
    and ships no native (C++/Swift) code. Windows metadata is read via `dart:ffi`
    calls into the Win32 version APIs (`version.dll`), and macOS reads the
    bundle's `Info.plist` in pure Dart (binary + XML).
  * Unsupported platforms (web, Linux, mobile) now throw `UnsupportedError`
    instead of a `MissingPluginException`.
  * The public API (`FlutterBin`, `BinaryFileMetadata`) is unchanged, so callers
    that only use the public API upgrade without code changes. Because the
    package no longer depends on Flutter, it can also be used from plain Dart.

* Dependencies:
  * Added `ffi`, `plist_parser`, and `path`; removed `flutter` and
    `plugin_platform_interface`.

* Tooling:
  * Tests migrated from `flutter_test` to `package:test`; native GoogleTest /
    XCTest harnesses removed. CI now runs `dart test` on Windows, macOS, and
    Linux, and builds the example app on Windows and macOS.

## 2.0.0

* **BREAKING**:
  * `getBinaryFileVersion` (and the `version` metadata field) now returns a
    semantic version (`major.minor.patch`) on all platforms. On Windows the
    trailing revision of the PE file version is dropped
    (e.g. `6.2.26100.8521` → `6.2.26100`).

* Fix:
  * Windows: `getBinaryFileVersion` now returns `null` (previously `false`) for
    files without version information, matching the documented contract.
  * Windows: a non-string `filePath` argument now returns an `INVALID_ARGUMENT`
    error instead of crashing the plugin.

* Improvements:
  * Documented the method-channel key contract; the Dart
    `BinaryFileMetadataJsonKey` enum is the single source of truth for the
    metadata keys.
  * Internal refactors: shared version-info loader (Windows) and shared
    Info.plist loader (macOS), with no change in behavior.

* Tooling:
  * Added a Windows native unit-test harness (GoogleTest) and real macOS
    XCTests.
  * Added CI (GitHub Actions) running Dart analyze/test, the Windows gtest
    suite, and the macOS XCTest suite on every push and pull request.

## 1.1.3

* Update:
  * update license


## 1.1.2

* Update:
  * update license

## 1.1.1

* Fix:
  * improvement of typos

## 1.1.0

* Added macOS platform support:
  * Retrieve file version information from macOS binary files
  * Extract metadata from Info.plist files in macOS applications
  * Support for both .app bundles and standalone binaries

## 1.0.0

Initial release of the flutter_bin plugin.

* Features:
  * Get basic version information from binary files on Windows
  * Get comprehensive metadata from Windows binary files including:
    * Product name
    * File description
    * Legal copyright
    * Original filename
    * Company name
  * Support for file path input or FilePicker selection
  * Cross-platform API design (currently implemented for Windows)

* Platforms:
  * Windows: Full implementation
  * Other platforms: API ready but not implemented yet
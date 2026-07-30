## 3.1.0

* Added the **PE image view**, a second way to read a Windows binary's version
  resource, in a new entry point `package:flutter_bin/pe.dart`:
  * `readPeVersionResource(path)` / `parsePeVersionResource(bytes)` return the
    version resource embedded in a PE image as a `PeVersionResource` — resource
    name, language id, four-part file and product versions, and every
    `StringFileInfo` table with every key it holds (not just the five strings
    `BinaryFileMetadata` maps). `value(key)` reads a single key, and
    `toBinaryFileMetadata()` maps onto the existing model so validation code
    written against `getBinaryFileMetadata` can be reused.
  * `readPeVersionResources` / `parsePeVersionResources` return every
    `RT_VERSION` leaf an image carries — one per language, and one per entry name
    — in resource-directory order. `selectPeVersionResource` exposes the rule the
    singular calls use: prefer the numeric id `1`, else the first leaf.
  * This reads binaries the Win32 version APIs cannot see at all: images whose
    `RT_VERSION` resource is stored under a **name string** instead of the
    numeric id `1`, which some `windres` builds emit (FileZilla 3.66.5, for
    example). `GetFileVersionInfoSizeW` returns 0 for those, so Explorer,
    PowerShell and `getBinaryFileMetadata` all report no version info while the
    data sits intact in the file.

* Existing APIs are unchanged. `getBinaryFileVersion` / `getBinaryFileMetadata`
  and `BinaryFileMetadata` behave exactly as in 3.0.0, and the image view is
  never substituted for them:
  * The two answer different questions. The OS view follows MUI satellite
    resources and is locale dependent; the image view reports what the binary
    itself carries. `C:\Windows\System32\mstsc.exe` reports `originalFilename`
    as `mstsc.exe.mui` through the OS view and `mstsc.exe` through the image
    view — both correct for their own question, so which one is acceptable stays
    the caller's decision. See the README's "Two Views of a Windows Binary".

* Implementation notes:
  * Pure Dart (`dart:io` + `dart:typed_data`), no FFI — the parser runs on any
    host, so its tests execute on the Linux CI job too.
  * Files are read through two windowed reads (headers, then the resource
    section) rather than loaded whole.
  * Version formatting is single-sourced: `fixedVersionParts` with
    `formatFixedVersion` (semver, revision dropped) and `formatFullVersion`
    (all four components) on top.

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
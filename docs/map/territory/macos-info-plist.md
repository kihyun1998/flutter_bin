# macOS Info.plist

## What it is
Reads version and metadata on macOS by resolving a path to the bundle's `Contents/Info.plist` and parsing it in Dart, either binary `bplist00` or XML. There is no FFI and no native code.

## Governing decisions
- [ADR-0003](../../adr/0003-version-string-is-semver.md): it assumes `CFBundleShortVersionString` is already semver and passes it through unchanged (see [Version is semver](../invariant/version-is-semver.md)).
- [ADR-0002](../../adr/0002-dart-enum-is-canonical-channel-key-source.md) governs the map keys.

## Design model
From the source:
- `resolveInfoPlistPath` uses `p.posix` explicitly so it resolves the same way from a Windows test host. For a `.app` path, if a `Contents` segment appears anywhere, it drops the last **two** components and appends `Contents/Info.plist`. Otherwise it treats the path as the bundle root.
- Binary and XML are routed by the `bplist00` magic. XML is UTF-8-decoded before `PlistParser.parseXml`, because the auto-detecting entrypoint mangles multi-byte UTF-8 such as `©` (`MacOSInfoPlistReader._load` comment).
- Field map: `version` ← `CFBundleShortVersionString`, `productName` ← `CFBundleName`, `fileDescription` ← `CFBundleGetInfoString`, `legalCopyright` ← `NSHumanReadableCopyright`, `originalFilename` ← `CFBundleExecutable`, `companyName` ← `''` (`readMetadata`).
- A value that is not a string reads as `''` (`_string`).
- Input bound: the whole plist file is read (`readAsBytesSync`), and nothing caps its size.

## Code
- `lib/src/macos/info_plist_reader.dart — resolveInfoPlistPath, MacOSInfoPlistReader, MacOSInfoPlistReader.readVersion, MacOSInfoPlistReader.readMetadata, MacOSInfoPlistReader._load, MacOSInfoPlistReader._isBinaryPlist`
- `lib/src/macos/flutter_bin_macos.dart — FlutterBinMacOS`
- Tests: `test/macos/info_plist_path_test.dart`, `test/macos/info_plist_reader_test.dart` and fixtures (any host), and `test/macos/real_bundle_macos_test.dart` (`@TestOn('mac-os')`).

## Reference behaviour
- Apple's `Info.plist` key documentation (`CFBundle*`), which is binding and summarized (`docs/agents/thegraph.md`). There is no pinned copy in the repo.

## Cross-cutting invariants
- [Version is semver](../invariant/version-is-semver.md)
- [Metadata key set](../invariant/metadata-key-set.md)
- [Absent reads as empty](../invariant/absent-reads-as-empty.md)

## Blast radius
- [Metadata model](metadata-model.md): the map keys are string literals that must equal the enum's.
- [Release](release.md): the README's "File Path Formats → macOS" documents which paths callers may pass, and this resolver decides whether they work.

## Known holes / open
- **The README documents a path that does not resolve.** It lists `/Applications/Example.app/Contents/MacOS/Example` as valid. `resolveInfoPlistPath` turns it into `.../Example.app/Contents/Contents/Info.plist`, which does not exist, so the call returns null or `{}`. The test `parity: a deep path inside a bundle reproduces the Swift quirk` pins that output for parity with the removed Swift plugin. Whether that parity is still wanted is undecided (maintainer, 2026-10-24).
- **The version is not checked as semver.** A `CFBundleShortVersionString` of `1.2.3.4` or `2.0` is returned as-is. ADR-0003 assumes Apple convention makes it semver. The maintainer was not aware of the gap (maintainer, 2026-10-24).

# macOS Info.plist

## What it is
Reads version and metadata on macOS by resolving a path to the bundle's `Contents/Info.plist` and parsing it in Dart, either binary `bplist00` or XML. There is no FFI and no native code.

## Governing decisions
- [ADR-0005](../../adr/0005-version-is-returned-as-the-source-states-it.md): it passes `CFBundleShortVersionString` through unchanged, by decision (see [Version is as the source states it](../invariant/version-is-as-the-source-states-it.md)). ADR-0003 had assumed the value was already semver. Apple specifies three period-separated integers, digits and periods only (Bundle Resources, `CFBundleShortVersionString`, read raw 2026-10-30), so a bundle carrying `2.0` or `1.2.3-beta` breaks Apple's rule, and this reader returns it anyway. ADR-0005's "free text" describes what bundles carry, not the spec.
- [ADR-0002](../../adr/0002-dart-enum-is-canonical-channel-key-source.md) governs the map keys.
- Path resolution no longer matches the removed Swift plugin (maintainer judgement, 2026-10-26, #36). The Swift resolver, which the 3.0.0 port copied, dropped the last two components whenever a `Contents` segment appeared anywhere in the path. That broke the README's `Contents/MacOS/<exe>` form, any bundle under a folder named `Contents`, and nested helper apps, and `Outer.app/Contents/Helper.app` silently returned the outer app's plist. The maintainer was shown a 13-input comparison of that rule against the innermost-`.app` rule: every input that resolved correctly before resolves identically after. They chose to drop parity and ship it as 3.1.1, a patch. The call did not cover non-`.app` bundle types.

## Design model
From the source:
- `resolveInfoPlistPath` uses `p.posix` explicitly so it resolves the same way from a Windows test host. The bundle root is the **innermost** path segment with the `.app` extension, and `Contents/Info.plist` is appended to it. A path with no `.app` segment is treated as the bundle root itself. So the bundle, any path inside it, and a nested helper `.app` each resolve to their own bundle's plist.
- Why the innermost `.app`: a helper app inside another app (`Outer.app/Contents/Helpers/Helper.app`) has its own `Info.plist`, and the innermost bundle is the one the path names. This follows Apple's `NSBundle` convention, which was read only as a summary and is unconfirmed (2026-10-26). Tracked: #45.
- Binary and XML are routed by the `bplist00` magic. XML is UTF-8-decoded before `PlistParser.parseXml`, because the auto-detecting entrypoint mangles multi-byte UTF-8 such as `©` (`MacOSInfoPlistReader._load` comment). Still true at `plist_parser` 0.3.0: `PlistParser.parseBytes` decodes XML with `String.fromCharCodes`, and `©` comes back as `Â©` (run 2026-10-30, Dart 3.13.7).
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
- [Version is as the source states it](../invariant/version-is-as-the-source-states-it.md)
- [Metadata key set](../invariant/metadata-key-set.md)
- [Absent reads as empty](../invariant/absent-reads-as-empty.md)

## Blast radius
- [Metadata model](metadata-model.md): the map keys are string literals that must equal the enum's.
- [Release](release.md): the README's "File Path Formats → macOS" documents which paths callers may pass, and this resolver decides whether they work.

## Known holes / open
- **Only `.app` bundles are recognised.** A `.appex`, `.bundle` or `.framework` path has no `.app` segment, so it is treated as a bundle root and gets `Contents/Info.plist` appended. That is wrong for a framework, whose plist is under `Resources/`. A `.appex` inside an app resolves to the enclosing `.app`'s plist (2026-10-26).
- **Three entries of the field map above read keys whose meaning differs from the field name.** `CFBundleGetInfoString` is obsolete: Apple's archived key reference says `NSHumanReadableCopyright` replaces it (Cocoa Keys, updated 2018-06-04), and the current Bundle Resources reference no longer lists it. `CFBundleExecutable` is "the name of the bundle's executable file", not the file's original name. `CFBundleName` is "a user-visible short name" of up to 15 characters, which the system may show only when `CFBundleDisplayName` is not set (Bundle Resources, read raw 2026-10-30). That most modern bundles leave `CFBundleGetInfoString` unset is #51's claim and unmeasured. Tracked: #51.
- **A non-string value reads as `''`** (`_string`), or `null` from `readVersion`, so it cannot be told from an absent key. Tracked: #48.

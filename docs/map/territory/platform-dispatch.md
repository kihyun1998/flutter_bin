# Platform dispatch

## What it is
The OS-view public API and how a call reaches a platform reader. `FlutterBin` forwards both methods to `FlutterBinPlatform.instance`. The default instance is picked through a conditional import, so web never compiles `dart:io` or `dart:ffi`. Platforms with no reader get an implementation that throws `UnsupportedError`.

## Governing decisions
**None.** The pure-Dart conversion that shaped this area (3.0.0, #23) is recorded in `CHANGELOG.md`, not in an ADR. [ADR-0004](../../adr/0004-pe-image-view-is-a-separate-api.md) decides that the PE image view never enters this dispatch, but it does not govern the dispatch itself.

## Design model
From the source:
- `createDefaultPlatform` comes in two variants. The `dart.library.io` one returns Windows → `FlutterBinFfiWindows`, macOS → `FlutterBinMacOS`, and anything else → `UnsupportedFlutterBin`. The other variant is used on web and always returns `UnsupportedFlutterBin`.
- `UnsupportedFlutterBin`'s methods are `async`, so the error arrives as a rejected `Future`, the same way the real implementations report failure.
- Platform wrappers hold no logic. They wrap a synchronous reader in the async signature, and on the metadata path they go through `BinaryFileMetadata.fromJson`.
- `FlutterBinPlatform.instance` is assignable so tests can swap in a fake (`test/flutter_bin_test.dart — MockFlutterBinPlatform`).
- The only input is a caller-supplied path string. Nothing here bounds or validates it, and each reader handles it.

## Code
- `lib/flutter_bin.dart — FlutterBin.getBinaryFileVersion, FlutterBin.getBinaryFileMetadata`
- `lib/flutter_bin_platform_interface.dart — FlutterBinPlatform, FlutterBinPlatform.instance`
- `lib/src/default_platform.dart — createDefaultPlatform` (web)
- `lib/src/default_platform_io.dart — createDefaultPlatform` (native)
- `lib/src/unsupported_platform.dart — UnsupportedFlutterBin`
- `lib/src/windows/flutter_bin_ffi_windows.dart — FlutterBinFfiWindows`
- `lib/src/macos/flutter_bin_macos.dart — FlutterBinMacOS`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Version is semver](../invariant/version-is-semver.md)
- [Metadata key set](../invariant/metadata-key-set.md)
- [Absent reads as empty](../invariant/absent-reads-as-empty.md)

## Blast radius
- [Windows OS view](windows-os-view.md): `FlutterBinFfiWindows` constructs `WindowsVersionReader`, which opens `version.dll` in its constructor. Choosing it on any host other than Windows fails at load time.
- [macOS Info.plist](macos-info-plist.md): its wrapper relies on the same dispatch, and its reader's map goes through `fromJson`.
- [Metadata model](metadata-model.md): every metadata result goes through `BinaryFileMetadata.fromJson`, so a change to the wrapper contract changes what callers see.
- [Example app](example-app.md): it calls `FlutterBin` directly, and CI builds it on Windows and macOS.

## Known holes / open
- Linux is listed as "❌ Planned" in the README's Platform Support table. Today it gets `UnsupportedFlutterBin`, and no reader exists. The PE image view already runs on Linux, but ADR-0004 keeps it out of this API.

# Absent reads as empty

## The fact
A path that is missing, unreadable, or not a recognised binary, or a file that carries no version data, yields an empty result and never throws: `null` from a single-value read, `{}` or `[]` from a collection read, and `''` for a missing field. The only exception is `UnsupportedError` on unsupported platforms. Source: `FlutterBin.getBinaryFileVersion` doc ("Returns null if the file doesn't exist or version information is not available") and `readPeVersionResource` doc ("Never throws for malformed input").

## Why it is cross-cutting
Each reader implements it its own way, with no shared helper:
- Windows OS view: `GetFileAttributesW` check, then the size and info calls; any failure returns `nullptr` (`WindowsVersionReader._loadVersionInfo`).
- macOS: an `existsSync` check, then `catch (_)` around read and parse (`MacOSInfoPlistReader._load`).
- PE image view: `_within` bounds on every read, plus catches of `FileSystemException` and `RangeError` (`readPeVersionResources`, `parsePeVersionResources`).

Callers write one null check per call. A reader that starts throwing breaks them on one platform only.

## Territories it holds in
- [Windows OS view](../territory/windows-os-view.md): `WindowsVersionReader._loadVersionInfo`
- [macOS Info.plist](../territory/macos-info-plist.md): `MacOSInfoPlistReader._load`
- [PE image view](../territory/pe-image-view.md): `readPeVersionResources`, `parsePeVersionResources`
- [Platform dispatch](../territory/platform-dispatch.md): the public doc comments state it

## What a violation looks like
An exception from `getBinaryFileMetadata` for a missing or corrupt file on one platform, where the others return empty.

## Discovery history
- Reading at `d06da3b`. Tests cover each site: `info_plist_reader_test.dart` ("missing plist", "corrupt binary plist", "malformed XML plist") and the `pe_version_reader_test.dart` group "returns null instead of throwing". The Windows FFI path is covered only on Windows (`version_reader_test.dart`).

## Where it will recur
Any new reader, and any new I/O or parse step inside an existing one. If a function reads a caller-supplied path, it is subject to this.

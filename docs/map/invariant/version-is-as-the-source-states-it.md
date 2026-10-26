# Version is as the source states it

## The fact
Every `version` the package returns through `getBinaryFileVersion`, `BinaryFileMetadata.version`, or `PeVersionResource.toBinaryFileMetadata` is the source's own value, unprocessed: on Windows all four parts of the `VS_FIXEDFILEINFO` file version (`major.minor.build.revision`), on macOS `CFBundleShortVersionString` exactly as the bundle writes it. The shape therefore differs by platform. Source: [ADR-0005](../../adr/0005-version-is-returned-as-the-source-states-it.md), which supersedes [ADR-0003](../../adr/0003-version-string-is-semver.md). It is a maintainer judgement, not a derivation (maintainer, 2026-10-26, #37).

## Why it is cross-cutting
Three sites produce `version`, and none of them calls another:
- the Windows OS view formats the fixed file version with `formatFullVersion` (`WindowsVersionReader._queryFixedFileInfo`);
- the PE image view copies `fixedFileVersion`, which the parser builds with the same `formatFullVersion` (`PeVersionResource.toBinaryFileMetadata`);
- macOS passes `CFBundleShortVersionString` through untouched (`MacOSInfoPlistReader.readVersion`, `readMetadata`).

A site that starts reshaping its value (truncating, padding, normalising) breaks the rule alone, with no compile error.

## Territories it holds in
- [Windows OS view](../territory/windows-os-view.md): `version_reader.dart — WindowsVersionReader._queryFixedFileInfo`, `version_info.dart — formatFullVersion`
- [PE image view](../territory/pe-image-view.md): `pe_version_resource.dart — PeVersionResource.toBinaryFileMetadata`
- [macOS Info.plist](../territory/macos-info-plist.md): `info_plist_reader.dart — MacOSInfoPlistReader.readVersion, MacOSInfoPlistReader.readMetadata`
- [Metadata model](../territory/metadata-model.md): the `version` field carries it.
- [Release](../territory/release.md): README and CHANGELOG promise it to consumers.

## What a violation looks like
The OS view and the image view report different versions for the same Windows file, or macOS reports a value the bundle does not contain (`2.0.0` for `2.0`). Three tests catch it, each mutation-tested on 2026-10-26 (reintroduced truncation, padding and suffix stripping each turned it red):
- `test/windows/pe_version_reader_test.dart` (any host): `toBinaryFileMetadata().version` equals `fixedFileVersion`.
- `test/windows/version_reader_test.dart` (Windows only): the OS view equals the image's `fixedFileVersion` for `kernel32.dll`, and reads the file version rather than the product version from a synthetic image whose two differ. System DLLs carry equal file and product versions, so a reader switched to the product version stayed green until the synthetic image was added.
- `test/macos/info_plist_reader_test.dart` (any host): `1.2.3.4`, `2.0` and `1.2.3-beta` come back unchanged from both calls.

## Discovery history
- ADR-0003 introduced a 3-part rule (2.0.0, `CHANGELOG.md`).
- The second Windows site came with the PE image view (#32, `adr/0004`).
- Reading at `d06da3b`: macOS did no check. The maintainer had not known this (maintainer, 2026-10-24).
- #37: the maintainer judged ADR-0003 wrong, and ADR-0005 replaced the 3-part rule with this one (maintainer, 2026-10-26).
- MUI: for `mstsc.exe` the OS view's fixed file version equals the image's (`10.0.26100.9711`, measured on one Windows 11 host, 2026-10-26). This holds while `GetFileVersionInfoW` takes the fixed info from the image itself rather than from the `.mui` satellite.

## Where it will recur
Any new function that fills a `version` field, such as a Linux reader (README "Planned"), is subject to this. Grep for writers with `git grep -n "version:\|'version'" -- lib/`.

# Version is semver

## The fact
Every `version` the package returns through `getBinaryFileVersion`, `BinaryFileMetadata.version`, or `PeVersionResource.toBinaryFileMetadata` is `major.minor.patch`: three dot-separated parts. Four-part versions exist only in fields named for them (`PeVersionResource.fixedFileVersion`, `fixedProductVersion`). Source: [ADR-0003](../../adr/0003-version-string-is-semver.md), and [ADR-0004](../../adr/0004-pe-image-view-is-a-separate-api.md) Consequences for the named 4-part field.

## Why it is cross-cutting
Three sites produce `version`, and none of them calls another:
- the Windows OS view truncates numerically (`formatFixedVersion`, built on `fixedVersionParts`);
- the PE image view truncates by splitting the already-formatted 4-part string (`PeVersionResource._semanticVersion`), and does not call `formatFixedVersion`;
- macOS passes `CFBundleShortVersionString` through untouched (`MacOSInfoPlistReader.readVersion`, `readMetadata`).

Callers compare versions across platforms and views on the strength of ADR-0003. A site that changes its shape alone breaks that comparison with no compile error.

## Territories it holds in
- [Windows OS view](../territory/windows-os-view.md): `version_info.dart — formatFixedVersion`
- [PE image view](../territory/pe-image-view.md): `pe_version_resource.dart — PeVersionResource._semanticVersion`
- [macOS Info.plist](../territory/macos-info-plist.md): `info_plist_reader.dart — MacOSInfoPlistReader.readVersion`. **This site holds the fact only by convention.**
- [Metadata model](../territory/metadata-model.md): the `version` field carries it.
- [Release](../territory/release.md): README and CHANGELOG promise it to consumers.

## What a violation looks like
The same app reports `1.2.3` on one path and `1.2.3.0` or `1.2` on another. It reproduces today on macOS for any bundle whose `CFBundleShortVersionString` does not have exactly three parts.

## Discovery history
- ADR-0003 introduced the 3-part rule (2.0.0, `CHANGELOG.md`).
- The second Windows site came with the PE image view (#32, `adr/0004`).
- Reading at `d06da3b`: macOS does no check. The maintainer had not known this (maintainer, 2026-10-24).

## Where it will recur
Any new function that fills a `version` field, such as a Linux reader (README "Planned"), is subject to this. Grep for writers with `git grep -n "version:\|'version'" -- lib/`.

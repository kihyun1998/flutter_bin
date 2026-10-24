# Metadata key set

## The fact
The keys of every reader's metadata map equal `BinaryFileMetadataJsonKey.values.map((e) => e.key)`: `version`, `productName`, `fileDescription`, `legalCopyright`, `originalFilename`, `companyName`. Source: [ADR-0002](../../adr/0002-dart-enum-is-canonical-channel-key-source.md).

## Why it is cross-cutting
Each reader writes the keys as its own string literals, and `BinaryFileMetadata.fromJson` reads them through the enum. Nothing links the literals to the enum, and a mismatched key silently becomes `''` because `fromJson` defaults missing keys. ADR-0002 Consequences: "the safety net is the test on each platform, not the type system."

## Territories it holds in
- [Metadata model](../territory/metadata-model.md): `binary_file_metadata.dart — BinaryFileMetadataJsonKey` (the source)
- [Windows OS view](../territory/windows-os-view.md): `version_reader.dart — _metadataStringFields`, plus the literal `'version'` in `readMetadata`
- [macOS Info.plist](../territory/macos-info-plist.md): `info_plist_reader.dart — MacOSInfoPlistReader.readMetadata`

## What a violation looks like
After a rename on one side, that field is `''` on one platform and correct on the other. No error is raised.

## Discovery history
- ADR-0002, from the method-channel era (C++/Swift literals).
- Reading at `d06da3b`: `test/models/binary_file_metadata_test.dart` pins the enum to a literal list, but no test compares either reader's map keys to the enum. The per-platform guards ADR-0002 relied on (`docs/method-channel-contract.md — What guards it`) were removed in 3.0.0.

## Where it will recur
Any function that returns a `Map<String, String>` destined for `BinaryFileMetadata.fromJson`. Grep with `git grep -n "fromJson(" -- lib/`.

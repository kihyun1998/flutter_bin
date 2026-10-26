# Metadata model

## What it is
The cross-platform result type `BinaryFileMetadata`, made of six string fields, and the key enum `BinaryFileMetadataJsonKey` that turns a reader's `Map<String, String>` into it.

## Governing decisions
- [ADR-0002](../../adr/0002-dart-enum-is-canonical-channel-key-source.md): the enum is the canonical key source. It was written for the method-channel era, and its "three-file change" now spans the two Dart readers plus the enum.
- [ADR-0004](../../adr/0004-pe-image-view-is-a-separate-api.md): the model is not extended with PE-only fields. Image-view data lives in `PeVersionResource`.

## Design model
- Every field defaults to `''`, and `fromJson` maps a missing key to `''` (`BinaryFileMetadata.fromJson`). An absent value and an empty value cannot be told apart. This holds by construction.
- `companyName` is always `''` on macOS (`MacOSInfoPlistReader.readMetadata`).
- `docs/method-channel-contract.md` is marked historical. It is kept only for the key names (its own header says so).

## Code
- `lib/models/binary_file_metadata.dart — BinaryFileMetadataJsonKey, BinaryFileMetadataJsonKey.key, BinaryFileMetadata, BinaryFileMetadata.fromJson`
- `test/models/binary_file_metadata_test.dart` pins the enum to a literal key list.

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Metadata key set](../invariant/metadata-key-set.md)
- [Version is as the source states it](../invariant/version-is-as-the-source-states-it.md)

## Blast radius
- [Windows OS view](windows-os-view.md): it emits the map keys as string literals that must equal the enum's `key`.
- [macOS Info.plist](macos-info-plist.md): it emits the same keys as string literals.
- [PE image view](pe-image-view.md): `PeVersionResource.toBinaryFileMetadata` builds the model by named parameters, so a renamed field breaks it at compile time and an added field is silently left `''`.
- [Release](release.md): the type is public API. A field change is a breaking change for the CHANGELOG and the version number.

## Known holes / open
- `docs/method-channel-contract.md — What guards it` names `windows/test/flutter_bin_plugin_test.cpp`, which no longer exists, and `RunnerTests.swift`, which is now a placeholder. The guards it describes are gone.

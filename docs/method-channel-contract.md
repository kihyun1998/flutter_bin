# Method-channel contract

The `flutter_bin` plugin talks to its platform implementations over a single
`MethodChannel` named `flutter_bin`. This document is the human-readable contract
that the Dart, Windows (C++), and macOS (Swift) sides must all agree on.

## Methods

| Method | Argument | Result |
| --- | --- | --- |
| `getBinaryFileVersion` | `filePath` (String, required) | semantic version `String` (`major.minor.patch`, e.g. `1.2.3`), or `null` when unavailable |
| `getBinaryFileMetadata` | `filePath` (String, required) | `Map<String, String>` keyed by the metadata keys below (empty map when unavailable) |

A missing or non-string `filePath` argument is answered with an
`INVALID_ARGUMENT` channel error.

## Metadata keys (the source of truth)

`getBinaryFileMetadata` returns exactly these keys:

- `version`
- `productName`
- `fileDescription`
- `legalCopyright`
- `originalFilename`
- `companyName`

**The canonical definition of this key set is the Dart enum
`BinaryFileMetadataJsonKey`** (`lib/models/binary_file_metadata.dart`). The native
implementations cannot import that enum, so they hardcode the same strings; when a
key is added, removed, or renamed, **all three implementations must change
together**. See [ADR-0002](adr/0002-dart-enum-is-canonical-channel-key-source.md).

### What guards it

- Dart: `test/models/binary_file_metadata_test.dart` pins the enum to the key list.
- Windows: `windows/test/flutter_bin_plugin_test.cpp`
  (`MetadataKeysMatchTheChannelContract`) asserts the returned key set.
- macOS: `example/macos/RunnerTests/RunnerTests.swift` asserts the mapped fields.

### Version format

The `version` value is a semantic version (`major.minor.patch`) on every platform.
Windows derives it from the PE file version `major.minor.build.revision`, dropping
the trailing revision; macOS returns `CFBundleShortVersionString` as-is (already a
short/semantic version by Apple convention). See
[ADR-0003](adr/0003-version-string-is-semver.md).

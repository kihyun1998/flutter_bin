# Windows OS view

## What it is
Reads a Windows binary's version resource the way the OS reports it: `dart:ffi` calls into `version.dll` (`GetFileVersionInfoSizeW`, `GetFileVersionInfoW`, `VerQueryValueW`) and `kernel32.dll` (`GetFileAttributesW`). It answers *"what does the OS report for this file?"* The answer follows MUI satellites, depends on the locale, and only finds the numeric `RT_VERSION` id `1`. This note also owns the platform-independent version-info helpers in `version_info.dart`, which the PE image view uses too.

## Governing decisions
- [ADR-0005](../../adr/0005-version-is-returned-as-the-source-states-it.md): `version` is all four parts of the fixed file version. It supersedes ADR-0003, which dropped the revision.
- [ADR-0004](../../adr/0004-pe-image-view-is-a-separate-api.md): this reader stays the only Windows source behind `getBinaryFileMetadata`. The image view is never substituted for it and never used as a fallback.
- [ADR-0001](../../adr/0001-standalone-windows-native-test-harness.md) governs a C++ harness that no longer exists (see Known holes).

## Design model
From the source and ADR-0004:
- String lookup tries `\StringFileInfo\040904B0\<key>` first. If that fails, it tries each `\VarFileInfo\Translation` entry, formatted as lowercase `%04x%04x` (`WindowsVersionReader._queryString`, `stringFileInfoSubBlock`). The doc comments describe this as a port of the removed C++ plugin's order.
- `version` comes from `VS_FIXEDFILEINFO.dwFileVersionMS/LS` through `formatFullVersion`, all four parts. Only those two DWORDs are read, but the full `_VsFixedFileInfo` layout is declared so the offsets are right. System DLLs carry equal file and product versions, so only a synthetic image whose two differ shows which pair is read (`test/windows/version_reader_test.dart`, mutation-tested 2026-10-26).
- `readMetadata` leaves out the `version` key when there is no fixed info, and sets every string field to a value or `''`.
- Memory is arena-scoped per call (`using`). Nothing outlives a call.
- Known divergence from the image view: `mstsc.exe` reports `originalFilename` as `mstsc.exe.mui` here (ADR-0004; `test/windows/real_pe_windows_test.dart`).
- `version_info.dart` has no `dart:ffi` or `dart:io`, so its tests run on every CI host. `fixedVersionParts` is the single split, with `formatFullVersion` (4 parts) on top. The 3-part `formatFixedVersion` was removed with ADR-0005.
- Input bound: the buffer size comes from `GetFileVersionInfoSizeW`. The OS bounds it.

## Code
- `lib/src/windows/version_reader.dart — WindowsVersionReader, WindowsVersionReader.readVersion, WindowsVersionReader.readMetadata, WindowsVersionReader._loadVersionInfo, WindowsVersionReader._queryFixedFileInfo, WindowsVersionReader._queryString, _metadataStringFields, _VsFixedFileInfo`
- `lib/src/windows/version_info.dart — fixedVersionParts, formatFullVersion, stringFileInfoSubBlock`
- `lib/src/windows/flutter_bin_ffi_windows.dart — FlutterBinFfiWindows`
- Tests: `test/windows/version_reader_test.dart` and `test/windows/real_pe_windows_test.dart` (both `@TestOn('windows')`), and `test/windows/version_info_test.dart` (any host).

## Reference behaviour
- Microsoft's PE / `VS_VERSIONINFO` / `VerQueryValue` documentation, which is binding and summarized (`docs/agents/thegraph.md`). There is no pinned copy in the repo.

## Cross-cutting invariants
- [Version is as the source states it](../invariant/version-is-as-the-source-states-it.md)
- [Metadata key set](../invariant/metadata-key-set.md)
- [Absent reads as empty](../invariant/absent-reads-as-empty.md)

## Blast radius
- [PE image view](pe-image-view.md): it uses `formatFullVersion` and `fixedVersionParts`, so a change to the split changes both views' versions. ADR-0004 also promises the two views pick the same leaf (id `1`).
- [Metadata model](metadata-model.md): `_metadataStringFields` keys must equal the enum keys.
- [Platform dispatch](platform-dispatch.md): the constructor opens DLLs, so it must only be built on Windows.

## Known holes / open
- ADR-0001 describes a `windows/test/` CMake/gtest harness that was removed with the C++ plugin in 3.0.0 (`CHANGELOG.md — 3.0.0`). The ADR still reads `Status: accepted`. Tracked: #39.
- `_queryString` takes the first translation that has the key. Which language a multi-language binary reports therefore depends on the order of the translation table, and the caller is not told which table a value came from; fields can come from different tables. This is unverified against Win32 Explorer behaviour. The image view returns every table (`PeStringTable`). Tracked: #50.
- **A table the lookup never tries is invisible.** Only `040904B0` and the `\VarFileInfo\Translation` entries are queried, so a table named by neither (Translation lists `0409 04E4`, the only table is `000004B0`) reads as `''` for every field, where the image view reports its values (`_queryString`). How often real binaries hit this is unmeasured. Tracked: #52.
- **A present but empty string is treated as absent.** `_queryStringSubBlock` returns null when `VerQueryValue` reports length 0, so `_queryString` moves to the next translation and can return another language's value instead of the empty one the first table states. Tracked: #52.
- **The product version is not exposed.** Only `dwFileVersionMS/LS` are read (`_queryFixedFileInfo`). Neither `dwProductVersion*` nor the `ProductVersion` string reaches the OS view, while the image view has `fixedProductVersion` and every string. Whether `version` should come from the numeric fixed info or the `FileVersion` string is also open. Tracked: #49.

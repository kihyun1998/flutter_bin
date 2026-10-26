# PE image view

## What it is
A pure-Dart parser that reads the version resource out of a PE file itself. It answers *"what is embedded in this image?"* without MUI and without locale dependence, and it finds `RT_VERSION` by type whatever the entry's name. It ships as a separate entry point, `package:flutter_bin/pe.dart`, with its own result type `PeVersionResource`, and runs on any host.

## Governing decisions
- [ADR-0004](../../adr/0004-pe-image-view-is-a-separate-api.md): a separate API and never a fallback. The singular API prefers id `1`. File reads are windowed.
- [ADR-0005](../../adr/0005-version-is-returned-as-the-source-states-it.md): `toBinaryFileMetadata` returns `fixedFileVersion` unchanged, all four parts. Until ADR-0005 it truncated to 3 parts under ADR-0003.

## Design model
From ADR-0004 and the source:
- Walk: DOS header → PE header (PE32 or PE32+) → data directory index 2 → resource directory type `16` → any name entry (id or string) → each language leaf → `VS_VERSIONINFO` block → `StringFileInfo` tables (`_readVersionLeaves`, `_parseVersionBlock`).
- Selection: `selectPeVersionResource` picks the `#1` leaf if present, else the first. Directories list named entries before ids, so without this rule an image carrying both would report the named one, a different resource from the OS view's.
- Tables stay separate and verbatim (`PeStringTable`). `PeVersionResource.value` takes the first table that has the key.
- Never throws on malformed input. Every read goes through `_within`, a corrupt leaf is skipped and its siblings are kept, and `RangeError` is caught as a backstop.
- **Input bounds.** The file reader reads at most `_headerProbeLength` (0x400) bytes of headers, re-read once if the section table runs past that, plus one window of `max(resourceSize, section.rawSize)` capped at the file length. Node lengths are clamped to the enclosing block. Nothing caps the window below the section's raw size, so a large resource section is read whole.
- Window limit: a version payload in a section other than the one holding the resource directory reads as null through the file reader, while `parsePeVersionResource` still finds it. No known toolchain emits that layout (ADR-0004).

## Code
- `lib/pe.dart` exports `readPeVersionResource, readPeVersionResources, parsePeVersionResource, parsePeVersionResources, selectPeVersionResource`.
- `lib/src/windows/pe_version_reader.dart — readPeVersionResources, _readFromHandle, _readAt, _parseHeaders, _readSections, _sectionFor, _rvaToOffset, _readVersionLeaves, _readLeaf, _entries, _readResourceName, _parseVersionBlock, _parseStringTables, _parseStringValues, _within`
- `lib/models/pe_version_resource.dart — PeStringTable, PeVersionResource, PeVersionResource.value, PeVersionResource.toBinaryFileMetadata`
- Tests: `test/windows/pe_version_reader_test.dart` (any host, builds images with `test/windows/pe_fixture_builder.dart`) and `test/windows/real_pe_windows_test.dart` (`@TestOn('windows')`).

## Reference behaviour
- Microsoft PE Format and `VS_VERSIONINFO` documentation, which is binding and summarized (`docs/agents/thegraph.md`). There is no pinned copy in the repo.
- FileZilla 3.66.5 is the shipped example of a string-named `RT_VERSION` (ADR-0004). It is not a fixture in the repo.

## Cross-cutting invariants
- [Version is as the source states it](../invariant/version-is-as-the-source-states-it.md)
- [Absent reads as empty](../invariant/absent-reads-as-empty.md)

## Blast radius
- [Windows OS view](windows-os-view.md): `version_info.dart` is shared, and the id-`1` rule exists to keep both views on the same leaf.
- [Metadata model](metadata-model.md): `toBinaryFileMetadata` builds it field by field, and a field added there stays `''` here.
- [Example app](example-app.md): it shows both views side by side (`_peResources`, `_peSelected`).
- [Release](release.md): `pe.dart`'s `show` list is the public surface. A symbol added to the parser is not public until it is listed there.

## Known holes / open
- **None.** beyond the window limit above, which ADR-0004 accepts.

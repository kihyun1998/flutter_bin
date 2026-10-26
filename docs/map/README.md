# Territory map

<!-- grill-map build stamp: 8e5a943 -->
<!-- grill-map synced at: d06da3b (2026-10-24) -->

The territory map. A comment's why, trap and measured value go to a note here. Notes are added as they come up, or all at once with `grill-map`, which also reads hand-written notes as leads and keeps their paths.

## What it answers
- **If I touch this, what else moves?** Open the territory, then follow `## Blast radius` and `## Cross-cutting invariants`.
- **What decision is this shape derived from?** Open the territory's `## Governing decisions`. A **None.** there is itself the answer: nothing recorded governs it.

`## Blast radius` is a checklist. An entry with nothing to do is a correct outcome.

## The repo in one paragraph
flutter_bin is a pure-Dart package that reads version metadata from desktop binaries. On Windows it gives two answers that are deliberately kept apart (ADR-0004): what the OS reports (FFI into `version.dll`) and what the image carries (a PE parser that runs on any host). On macOS it parses the bundle's `Info.plist`. Everything else throws `UnsupportedError`. The C++ and Swift plugins were removed in 3.0.0, and ADR-0001 and ADR-0002 still describe that era. The largest gap is that three cross-platform contracts (version as the source states it, key set, empty-on-absent) are each implemented separately per reader. Only `version` is tested across readers, and only between the two Windows views (`test/windows/version_reader_test.dart`); nothing compares Windows with macOS.

## Territories
- [Platform dispatch](territory/platform-dispatch.md)
- [Metadata model](territory/metadata-model.md)
- [Windows OS view](territory/windows-os-view.md)
- [PE image view](territory/pe-image-view.md)
- [macOS Info.plist](territory/macos-info-plist.md)
- [Release](territory/release.md)
- [Example app](territory/example-app.md)

## Cross-cutting invariants
- [Version is as the source states it](invariant/version-is-as-the-source-states-it.md)
- [Metadata key set](invariant/metadata-key-set.md)
- [Absent reads as empty](invariant/absent-reads-as-empty.md)

## Conventions
- Section headings are identical in every note. An empty section says **None.**
- Code is cited by symbol (`file — Symbol`), never by line.
- Links are relative markdown. A fact another file owns is linked, not copied.
- Every claim carries its evidence (a symbol, a record, a commit) or its source and date, e.g. `(maintainer, 2026-10-24)`.

## What it cannot answer
Source files and issues are text inside notes, not nodes. The map does not tell you who calls a symbol, so grep for that.

## Scope
Out of scope: `CODE.md` and the `codemd*` binaries (a generated code snapshot, excluded from pub), `docs/agents/` (agent tooling), and editor files (`.vscode/`, `*.iml`, `.metadata`). A territory appears when something in the repo commits to it: code, a decision record, or an open issue with a design. Linux support is a README "Planned" line with nothing behind it, so it is a hole in [Platform dispatch](territory/platform-dispatch.md), not a note.

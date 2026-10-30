# Release

## What it is
Everything that turns the source into what consumers get, and keeps it green: the pub package (`pubspec.yaml`, `.pubignore`), the user-facing docs that ship with it (`README.md`, `CHANGELOG.md`), and CI.

## Governing decisions
**None.** No ADR covers versioning, publishing or CI. The breaking-change discipline shows only in the CHANGELOG (3.0.0, ADR-0003's 2.0.0 note).

## Design model
From the files:
- The public surface is two libraries: `lib/flutter_bin.dart` (OS view) and `lib/pe.dart` (image view, an explicit `show` list). `lib/src/` is private by convention, but tests import it directly.
- `.pubignore` keeps `docs/`, `CLAUDE.md`, `CODE.md`/`codemd*`, and most of `example/windows` and `example/macos` out of the archive. `docs/map/` is excluded as part of `docs/`.
- CI (`.github/workflows/ci.yml`): on Ubuntu, Windows and macOS it runs `dart format --set-exit-if-changed`, `dart analyze` and `dart test`. `@TestOn` annotations route each platform's real-binary tests to its runner. A second job builds the example on Windows and macOS. Flutter is pinned through `FLUTTER_VERSION`.
- No lockfile is committed. Dependencies are resolved from `pubspec.yaml` alone (#35).
- Dependabot (`.github/dependabot.yml`): root pub weekly with `increase-if-necessary`, ungrouped; `/example` pub and `github-actions` monthly, each as one group; every PR labelled `needs-triage`. Without a lockfile, `increase-if-necessary` opens a root PR only when a release falls outside the caret, which at `0.x` means every minor. Such a PR raises the floor for consumers, so each one stays a single decision. Nothing ships from `example/`, so its PRs are grouped (#35). The CI Flutter pin (`FLUTTER_VERSION`) is an env value, not an action version, so Dependabot never bumps it.
- Dependabot's first run, 2026-10-24, matched the configuration: two ungrouped root PRs, each crossing its caret (#43 `lints` `^5.0.0` → `^6.1.0`, #44 `plist_parser` `^0.2.7` → `^0.3.0`), one `actions` group PR (#41 `actions/checkout` 5 → 7), one `example` group PR (#42), each labelled `needs-triage`. The root PRs rewrote the constraint floor, which is what `increase-if-necessary` on `pub` is documented to do.
- `CHANGELOG.md` can carry an unreleased section ahead of `pubspec.yaml`'s version: `4.0.0 (unreleased)` collects the breaking changes of the 4.0.0 theme while the package stays at 3.1.1, so callers adapt once (commit 14e117a, 2026-10-26). Tracked: #47.
- The release bar is `pub-ready` (`docs/agents/thegraph.md — Release`).

## Code
- `pubspec.yaml`, `.pubignore`, `CHANGELOG.md`, `README.md`, `analysis_options.yaml`
- `.github/workflows/ci.yml — jobs.test, jobs.example`
- `.github/dependabot.yml — updates`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Version is as the source states it](../invariant/version-is-as-the-source-states-it.md): the README and CHANGELOG state the contract to consumers.

## Blast radius
- [Example app](example-app.md): CI's `example` job builds it, so a dependency or API change that breaks the example turns CI red.
- [Windows OS view](windows-os-view.md): `pubspec.yaml`'s `ffi` constraint. A bump changes the binding layer every Win32 call goes through, and only the `@TestOn('windows')` tests exercise it.
- [macOS Info.plist](macos-info-plist.md): the `plist_parser` and `path` constraints. A `plist_parser` bump can make the UTF-8 pre-decode in `MacOSInfoPlistReader._load` unnecessary, or break it.
- [Platform dispatch](platform-dispatch.md) and [PE image view](pe-image-view.md): they own the two exported libraries, so any change to their public symbols is a release decision.

## Known holes / open
**None.**

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

## Code
- `pubspec.yaml`, `.pubignore`, `CHANGELOG.md`, `README.md`, `analysis_options.yaml`
- `.github/workflows/ci.yml — jobs.test, jobs.example`
- `.github/dependabot.yml — updates`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Version is semver](../invariant/version-is-semver.md): the README and CHANGELOG state the 3-part contract to consumers.

## Blast radius
- [Example app](example-app.md): CI's `example` job builds it, so a dependency or API change that breaks the example turns CI red.
- [Windows OS view](windows-os-view.md): `pubspec.yaml`'s `ffi` constraint. A bump changes the binding layer every Win32 call goes through, and only the `@TestOn('windows')` tests exercise it.
- [macOS Info.plist](macos-info-plist.md): the `plist_parser` and `path` constraints. A `plist_parser` bump can make the UTF-8 pre-decode in `MacOSInfoPlistReader._load` unnecessary, or break it.
- [Platform dispatch](platform-dispatch.md) and [PE image view](pe-image-view.md): they own the two exported libraries, so any change to their public symbols is a release decision.

## Known holes / open
- Dependabot's first run is unobserved. A configuration error shows only in the repository's Dependabot status after merge to the default branch (#35).
- Dependabot's support for `versioning-strategy` on `pub` rests on GitHub's options reference ("Supported by: … `pub` …"), read as a summary. It needs confirming against the first real root PR.

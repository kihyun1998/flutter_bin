# Example app

## What it is
A Flutter desktop app in `example/` that lets a user pick a file and shows both the OS view and the PE image view of it. It is the only consumer of the package in the repo, and it is the package's documentation in runnable form.

## Governing decisions
**None.**

## Design model
- It depends on the package through a path dependency (`example/pubspec.yaml`) and imports both `flutter_bin.dart` and `pe.dart` (`example/lib/main.dart`).
- CI builds it on Windows and macOS (`flutter build windows`, `flutter build macos --debug`). It is not built on Linux.
- `example/macos/RunnerTests/RunnerTests.swift` is a placeholder kept so the Xcode test target stays valid (its own comment says so).

## Code
- `example/lib/main.dart — BinaryMetadataScreen, _BinaryMetadataScreenState`
- `example/integration_test/plugin_integration_test.dart`, `example/test/widget_test.dart`
- `example/windows/`, `example/macos/`: generated Flutter runner projects

## Reference behaviour
**None.**

## Cross-cutting invariants
**None.**

## Blast radius
- [Release](release.md): the CI `example` job and `.pubignore`'s example exclusions.

## Known holes / open
- **None.**

# Standalone Windows native test harness

Status: accepted

The Windows plugin holds all of the real logic (Win32 version-resource parsing) yet had no runnable test — the shipped `windows/test/*.cpp` was orphaned template code testing a `getPlatformVersion` method the plugin never implemented, and nothing built it. We added a self-contained CMake project at `windows/test/CMakeLists.txt` that compiles the plugin sources together with the Flutter C++ client-wrapper (from the SDK's engine artifacts) and GoogleTest (via `FetchContent`), so `HandleMethodCall` can be exercised directly. It derives the SDK path from `flutter` on `PATH` (or `-DFLUTTER_ROOT`), so it runs without a pre-built example app.

## Considered Options

- **Test the native code through the Flutter example app's integration tests.** Rejected: the defensive behaviors we most need to test (a non-string `filePath` reaching the handler) are unreachable from Dart, whose typed API (`String filePath`) can't produce them. Only a C++ unit test constructing a raw `EncodableMap` can.
- **Leave native code untested, cover only the Dart facade.** Rejected: the Dart layer has no logic; the bugs live in native code. This is exactly where the first run of the harness caught a real defect (see ADR context below).
- **Standalone gtest harness (chosen).** Decoupled from the example build, fast, and reusable for the remaining native refactors.

## Consequences

- Running the suite requires the Flutter Windows engine artifacts to be cached (any `flutter` command does this) and network access on first configure (GoogleTest download).
- The test executable links `flutter_windows.dll.lib`, so `flutter_windows.dll` is copied next to it post-build.
- Standing this up immediately surfaced a latent bug: `getBinaryFileVersion` returned `bool false` instead of `null` for missing files (`result->Success(nullptr)` decoding through `nullptr -> bool`). Fixed with `result->Success()`.

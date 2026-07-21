import '../flutter_bin_method_channel.dart';
import '../flutter_bin_platform_interface.dart';

/// Fallback used on platforms without `dart:io` / `dart:ffi` (e.g. web).
///
/// This variant is selected when `dart.library.io` is unavailable, so the FFI
/// implementation is never statically linked into the compilation graph. That
/// keeps a consuming app that also targets web compilable, even though this
/// package only actually runs on desktop.
FlutterBinPlatform createDefaultPlatform() => MethodChannelFlutterBin();

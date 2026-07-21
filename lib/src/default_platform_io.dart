import 'dart:io' show Platform;

import '../flutter_bin_platform_interface.dart';
import 'macos/flutter_bin_macos.dart';
import 'unsupported_platform.dart';
import 'windows/flutter_bin_ffi_windows.dart';

/// Default used on native platforms, where `dart:io` and `dart:ffi` exist.
///
/// Windows is served by the pure-Dart [FlutterBinFfiWindows] (dart:ffi into the
/// Win32 version APIs) and macOS by [FlutterBinMacOS] (pure-Dart Info.plist
/// parsing); every other native platform throws [UnsupportedError].
FlutterBinPlatform createDefaultPlatform() {
  if (Platform.isWindows) {
    return FlutterBinFfiWindows();
  }
  if (Platform.isMacOS) {
    return FlutterBinMacOS();
  }
  return UnsupportedFlutterBin();
}

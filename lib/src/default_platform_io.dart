import 'dart:io' show Platform;

import '../flutter_bin_method_channel.dart';
import '../flutter_bin_platform_interface.dart';
import 'windows/flutter_bin_ffi_windows.dart';

/// Default used on native platforms, where `dart:io` and `dart:ffi` exist.
///
/// Windows is served by the pure-Dart [FlutterBinFfiWindows] (dart:ffi into the
/// Win32 version APIs); every other platform still routes through the method
/// channel until its native code is migrated.
FlutterBinPlatform createDefaultPlatform() {
  if (Platform.isWindows) {
    return FlutterBinFfiWindows();
  }
  return MethodChannelFlutterBin();
}

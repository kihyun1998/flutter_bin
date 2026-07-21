import '../flutter_bin_platform_interface.dart';
import 'unsupported_platform.dart';

/// Selected when `dart:io` is unavailable (web). flutter_bin has no web
/// implementation, so calls throw [UnsupportedError]. Keeping this variant off
/// the `dart:io`/`dart:ffi` code path is what lets a web-targeting consumer of
/// this package still compile.
FlutterBinPlatform createDefaultPlatform() => UnsupportedFlutterBin();

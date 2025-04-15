import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_bin_platform_interface.dart';

/// An implementation of [FlutterBinPlatform] that uses method channels.
class MethodChannelFlutterBin extends FlutterBinPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_bin');

  @override
  Future<String?> getBinaryFileVersion(String filePath) async {
    final version = await methodChannel
        .invokeMethod<String?>('getBinaryFileVersion', {'filePath': filePath});
    return version;
  }
}

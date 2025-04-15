import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_bin_platform_interface.dart';
import 'models/binary_file_metadata.dart';

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

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) async {
    final Map<String, dynamic>? result = await methodChannel
        .invokeMapMethod<String, dynamic>(
            'getBinaryFileMetadata', {'filePath': filePath});

    if (result == null) {
      return BinaryFileMetadata();
    }

    return BinaryFileMetadata.fromJson(result);
  }
}

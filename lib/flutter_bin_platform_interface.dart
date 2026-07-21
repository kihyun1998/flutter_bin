import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models/binary_file_metadata.dart';
// Selects the default implementation without statically linking `dart:ffi` on
// platforms that can't compile it (web): the `_io` variant is used only when
// `dart:io` is available, i.e. on native platforms.
import 'src/default_platform.dart'
    if (dart.library.io) 'src/default_platform_io.dart';

abstract class FlutterBinPlatform extends PlatformInterface {
  /// Constructs a FlutterBinPlatform.
  FlutterBinPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBinPlatform _instance = createDefaultPlatform();

  /// The default instance of [FlutterBinPlatform] to use.
  ///
  /// On native platforms this is the pure-Dart FFI implementation on Windows
  /// and the method channel elsewhere; the selection lives in
  /// `createDefaultPlatform` (conditionally imported so web never links
  /// `dart:ffi`).
  static FlutterBinPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBinPlatform] when
  /// they register themselves.
  static set instance(FlutterBinPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Gets the version of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns the version string of the file or null if not available.
  Future<String?> getBinaryFileVersion(String filePath) {
    throw UnimplementedError(
        'getBinaryFileVersion() has not been implemented.');
  }

  /// Gets comprehensive metadata of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns a [BinaryFileMetadata] object containing available metadata.
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) {
    throw UnimplementedError(
        'getBinaryFileMetadata() has not been implemented.');
  }
}

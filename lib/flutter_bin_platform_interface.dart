import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_bin_method_channel.dart';

abstract class FlutterBinPlatform extends PlatformInterface {
  /// Constructs a FlutterBinPlatform.
  FlutterBinPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBinPlatform _instance = MethodChannelFlutterBin();

  /// The default instance of [FlutterBinPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBin].
  static FlutterBinPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBinPlatform] when
  /// they register themselves.
  static set instance(FlutterBinPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getBinaryFileVersion(String filePath) {
    throw UnimplementedError(
        'getBinaryFileVersion() has not been implemented.');
  }

  Future<String?> pickFileAndGetVersion() {
    throw UnimplementedError(
        'pickFileAndGetVersion() has not been implemented.');
  }
}

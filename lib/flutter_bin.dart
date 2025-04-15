import 'flutter_bin_platform_interface.dart';

class FlutterBin {
  /// Gets the version of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns the version string of the file (e.g. '1.2.3.4').
  /// Returns null if the file doesn't exist or version information is not available.
  Future<String?> getBinaryFileVersion(String filePath) {
    return FlutterBinPlatform.instance.getBinaryFileVersion(filePath);
  }
}

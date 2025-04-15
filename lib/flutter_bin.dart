import 'flutter_bin_platform_interface.dart';
import 'models/binary_file_metadata.dart';

export 'models/binary_file_metadata.dart';

class FlutterBin {
  /// Gets the version of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns the version string of the file (e.g. '1.2.3.4').
  /// Returns null if the file doesn't exist or version information is not available.
  Future<String?> getBinaryFileVersion(String filePath) {
    return FlutterBinPlatform.instance.getBinaryFileVersion(filePath);
  }

  /// Gets comprehensive metadata of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns a [BinaryFileMetadata] object containing available metadata.
  /// Fields may be null if the corresponding information is not available.
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) {
    return FlutterBinPlatform.instance.getBinaryFileMetadata(filePath);
  }
}

import 'flutter_bin_platform_interface.dart';
import 'models/binary_file_metadata.dart';

export 'models/binary_file_metadata.dart';

class FlutterBin {
  /// Gets the version of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns the semantic version string of the file (e.g. '1.2.3').
  /// Returns null if the file doesn't exist or version information is not available.
  Future<String?> getBinaryFileVersion(String filePath) {
    return FlutterBinPlatform.instance.getBinaryFileVersion(filePath);
  }

  /// Gets comprehensive metadata of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns a [BinaryFileMetadata] object containing available metadata.
  /// Fields default to an empty string when the corresponding information is
  /// not available. The `version` field is a semantic version (e.g. '1.2.3').
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) {
    return FlutterBinPlatform.instance.getBinaryFileMetadata(filePath);
  }
}

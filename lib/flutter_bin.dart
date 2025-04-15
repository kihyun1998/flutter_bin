// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'flutter_bin_platform_interface.dart';

class FlutterBin {
  /// Gets the version of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns the version string of the file (e.g. '1.2.3.4').
  /// Returns null if version information is not available.
  Future<String?> getBinaryFileVersion(String filePath) {
    return FlutterBinPlatform.instance.getBinaryFileVersion(filePath);
  }

  /// Shows a file picker dialog and returns the version of the selected file.
  ///
  /// Returns null if the user cancels the file selection or if version
  /// information is not available.
  Future<String?> pickFileAndGetVersion() {
    return FlutterBinPlatform.instance.pickFileAndGetVersion();
  }
}

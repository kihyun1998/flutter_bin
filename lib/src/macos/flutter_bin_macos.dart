import '../../flutter_bin_platform_interface.dart';
import '../../models/binary_file_metadata.dart';
import 'info_plist_reader.dart';

/// macOS implementation of [FlutterBinPlatform] backed by pure-Dart Info.plist
/// parsing — no method channel, no native plugin.
///
/// The synchronous file read + plist parse are wrapped in the async signatures
/// the public API exposes.
class FlutterBinMacOS extends FlutterBinPlatform {
  FlutterBinMacOS({MacOSInfoPlistReader? reader})
      : _reader = reader ?? MacOSInfoPlistReader();

  final MacOSInfoPlistReader _reader;

  @override
  Future<String?> getBinaryFileVersion(String filePath) async {
    return _reader.readVersion(filePath);
  }

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) async {
    return BinaryFileMetadata.fromJson(_reader.readMetadata(filePath));
  }
}

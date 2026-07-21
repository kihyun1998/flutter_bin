import '../../flutter_bin_platform_interface.dart';
import '../../models/binary_file_metadata.dart';
import 'version_reader.dart';

/// Windows implementation of [FlutterBinPlatform] backed by `dart:ffi` calls
/// into the Win32 version APIs — no method channel, no native plugin.
///
/// The synchronous FFI reads are wrapped in the async signatures the public
/// API exposes.
class FlutterBinFfiWindows extends FlutterBinPlatform {
  FlutterBinFfiWindows({WindowsVersionReader? reader})
      : _reader = reader ?? WindowsVersionReader();

  final WindowsVersionReader _reader;

  @override
  Future<String?> getBinaryFileVersion(String filePath) async {
    return _reader.readVersion(filePath);
  }

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) async {
    return BinaryFileMetadata.fromJson(_reader.readMetadata(filePath));
  }
}

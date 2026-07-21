import '../flutter_bin_platform_interface.dart';
import '../models/binary_file_metadata.dart';

/// Implementation used on platforms flutter_bin doesn't support (web, Linux,
/// mobile). Every call throws [UnsupportedError], surfacing the desktop-only
/// scope explicitly instead of via a missing-plugin error.
///
/// The methods are `async` so the error is delivered as a rejected `Future`,
/// matching the Windows/macOS implementations — `await`, `.catchError`, and
/// `unawaited` all observe it the same way.
class UnsupportedFlutterBin extends FlutterBinPlatform {
  Never _unsupported() =>
      throw UnsupportedError('flutter_bin only supports Windows and macOS.');

  @override
  Future<String?> getBinaryFileVersion(String filePath) async => _unsupported();

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) async =>
      _unsupported();
}

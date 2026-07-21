import 'models/binary_file_metadata.dart';
// Selects the default implementation without statically linking `dart:io` /
// `dart:ffi` on platforms that can't compile them (web): the `_io` variant is
// used only when `dart:io` is available, i.e. on native platforms.
import 'src/default_platform.dart'
    if (dart.library.io) 'src/default_platform_io.dart';

/// The platform dispatch seam behind the public [FlutterBin] API.
///
/// A plain-Dart abstraction — the package no longer depends on Flutter or
/// `plugin_platform_interface`. Tests may replace [instance] with a fake.
abstract class FlutterBinPlatform {
  FlutterBinPlatform();

  /// The active implementation. Defaults to the pure-Dart FFI reader on
  /// Windows, the Info.plist reader on macOS, and an implementation that throws
  /// [UnsupportedError] on every other platform. Assignable so tests can
  /// substitute a fake.
  static FlutterBinPlatform instance = createDefaultPlatform();

  /// Gets the version of a binary file.
  /// See `FlutterBin.getBinaryFileVersion`.
  Future<String?> getBinaryFileVersion(String filePath);

  /// Gets comprehensive metadata of a binary file.
  /// See `FlutterBin.getBinaryFileMetadata`.
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath);
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:plist_parser/plist_parser.dart';

// macOS paths always use POSIX separators, so use the posix context explicitly
// — otherwise this resolves with `\` when exercised from a Windows test host.
final p.Context _posix = p.posix;

/// Resolves the input path to the bundle's `Contents/Info.plist`.
///
/// The bundle root is the innermost path segment with the `.app` extension, so
/// the bundle itself, any path inside it (`Contents/MacOS/<exe>`,
/// `Contents/Info.plist`, ...) and a nested helper `.app` each resolve to their
/// own bundle's plist. A path with no `.app` segment is treated as the bundle
/// root itself.
String resolveInfoPlistPath(String filePath) {
  final segments = _posix.split(filePath);
  final appIndex =
      segments.lastIndexWhere((segment) => _posix.extension(segment) == '.app');
  final bundleRoot =
      appIndex < 0 ? filePath : _posix.joinAll(segments.take(appIndex + 1));
  return _posix.join(bundleRoot, 'Contents', 'Info.plist');
}

/// Reads a macOS bundle's `Info.plist` in pure Dart — resolve the path, read the
/// file with `dart:io`, and parse it (binary `bplist00` or XML) via
/// `plist_parser`. No FFI, no native code.
///
/// This is the Dart port of `macos/Classes/FlutterBinPlugin.swift`: a missing
/// or unparseable plist yields null / an empty map (matching Swift's
/// `NSDictionary(contentsOfFile:)` returning nil), and individual absent string
/// fields default to `''`.
class MacOSInfoPlistReader {
  MacOSInfoPlistReader({PlistParser? parser})
      : _parser = parser ?? PlistParser();

  final PlistParser _parser;

  /// Returns `CFBundleShortVersionString`, or null when no plist can be read.
  String? readVersion(String filePath) {
    final value = _load(filePath)?['CFBundleShortVersionString'];
    return value is String ? value : null;
  }

  /// Returns the metadata map. Empty when no plist can be read; absent string
  /// fields default to `''`. `companyName` is always empty — macOS Info.plists
  /// don't carry an equivalent field.
  Map<String, String> readMetadata(String filePath) {
    final plist = _load(filePath);
    if (plist == null) return {};

    return {
      'version': _string(plist, 'CFBundleShortVersionString'),
      'productName': _string(plist, 'CFBundleName'),
      'fileDescription': _string(plist, 'CFBundleGetInfoString'),
      'legalCopyright': _string(plist, 'NSHumanReadableCopyright'),
      'originalFilename': _string(plist, 'CFBundleExecutable'),
      'companyName': '',
    };
  }

  // Resolves + reads + parses the plist. Returns null when the file is absent
  // or can't be parsed as a property list.
  //
  // Binary vs XML is routed explicitly by the `bplist00` magic: `plist_parser`'s
  // auto-detecting entrypoint decodes XML bytes with `String.fromCharCodes`,
  // which mangles multi-byte UTF-8 (e.g. `©`), so XML is UTF-8 decoded here
  // before parsing.
  Map? _load(String filePath) {
    final file = File(resolveInfoPlistPath(filePath));
    if (!file.existsSync()) return null;
    try {
      final bytes = file.readAsBytesSync();
      if (_isBinaryPlist(bytes)) {
        return _parser.parseBinaryBytes(bytes);
      }
      return _parser.parseXml(utf8.decode(bytes));
    } catch (_) {
      // Any read/parse failure (corrupt bytes, malformed XML, bad UTF-8)
      // resolves to null, mirroring Swift's nil-on-failure semantics.
      return null;
    }
  }

  static bool _isBinaryPlist(Uint8List bytes) =>
      bytes.length >= 8 &&
      String.fromCharCodes(bytes.sublist(0, 8)) == 'bplist00';

  String _string(Map plist, String key) {
    final value = plist[key];
    return value is String ? value : '';
  }
}

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
/// Dart port of the Swift `resolveInfoPlistPath`. When [filePath] is a `.app`
/// bundle (extension `.app`, or any path containing `.app/`) the bundle root is
/// located and `Contents/Info.plist` is appended; otherwise [filePath] itself
/// is treated as the bundle root. When the path already runs through a
/// `Contents` segment the last two components are dropped first so an
/// already-resolved plist path round-trips instead of doubling up.
String resolveInfoPlistPath(String filePath) {
  final isAppBundle =
      _posix.extension(filePath) == '.app' || filePath.contains('.app/');

  if (isAppBundle) {
    final insideContents = _posix.split(filePath).contains('Contents');
    final bundleRoot =
        insideContents ? _posix.dirname(_posix.dirname(filePath)) : filePath;
    return _posix.join(bundleRoot, 'Contents', 'Info.plist');
  }

  return _posix.join(filePath, 'Contents', 'Info.plist');
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

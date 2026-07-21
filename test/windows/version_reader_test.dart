@TestOn('windows')
library;

import 'dart:io';

import 'package:flutter_bin/src/windows/flutter_bin_ffi_windows.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end checks that the FFI path actually reads a real PE version
/// resource. These run only on Windows (the `@TestOn('windows')` annotation
/// makes them a no-op on the Linux/macOS CI jobs).
void main() {
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  final kernel32 = '$systemRoot\\System32\\kernel32.dll';
  final platform = FlutterBinFfiWindows();

  final semver = RegExp(r'^\d+\.\d+\.\d+$');

  test('reads a 3-part semantic version from a system DLL', () async {
    final version = await platform.getBinaryFileVersion(kernel32);
    expect(version, isNotNull);
    expect(version, matches(semver),
        reason: 'expected major.minor.build, got "$version"');
  });

  test('reads metadata strings from a system DLL', () async {
    final metadata = await platform.getBinaryFileMetadata(kernel32);

    // The version field mirrors the standalone version call.
    expect(metadata.version, matches(semver));
    // kernel32 carries these fields; assert non-empty rather than exact text
    // to stay locale-independent.
    expect(metadata.productName, isNotEmpty);
    expect(metadata.companyName, isNotEmpty);
    expect(metadata.originalFilename, isNotEmpty);
    // fileDescription may live under a non-default language block, so a
    // non-empty value here also exercises the \VarFileInfo\Translation fallback.
    expect(metadata.fileDescription, isNotEmpty);
  });

  test('returns null / empty for a file with no version resource', () async {
    final tempDir = Directory.systemTemp.createTempSync('flutter_bin_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final plainFile = File('${tempDir.path}\\plain.txt')
      ..writeAsStringSync('not a PE file');

    expect(await platform.getBinaryFileVersion(plainFile.path), isNull);

    final metadata = await platform.getBinaryFileMetadata(plainFile.path);
    expect(metadata.version, '');
    expect(metadata.productName, '');
    expect(metadata.companyName, '');
  });

  test('returns null for a missing file', () async {
    final missing = '$systemRoot\\System32\\does_not_exist_flutter_bin.dll';
    expect(await platform.getBinaryFileVersion(missing), isNull);
    expect((await platform.getBinaryFileMetadata(missing)).version, '');
  });

  test('handles non-ASCII (Unicode) paths', () async {
    // Copy a real versioned DLL to a Korean-named path to exercise the
    // UTF-16 path marshalling end-to-end.
    final tempDir = Directory.systemTemp.createTempSync('flutter_bin_유니코드');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final copied = '${tempDir.path}\\테스트_바이너리.dll';
    File(kernel32).copySync(copied);

    final version = await platform.getBinaryFileVersion(copied);
    expect(version, matches(semver));
  });
}

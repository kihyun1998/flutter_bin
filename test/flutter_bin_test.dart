import 'dart:io' show Platform;

import 'package:flutter_bin/flutter_bin.dart';
import 'package:flutter_bin/flutter_bin_platform_interface.dart';
import 'package:flutter_bin/src/macos/flutter_bin_macos.dart';
import 'package:flutter_bin/src/unsupported_platform.dart';
import 'package:flutter_bin/src/windows/flutter_bin_ffi_windows.dart';
import 'package:test/test.dart';

class MockFlutterBinPlatform extends FlutterBinPlatform {
  @override
  Future<String?> getBinaryFileVersion(String filePath) async => '1.2.3.4';

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) async {
    return BinaryFileMetadata(
      version: '1.2.3.4',
      productName: 'Mock Product',
      fileDescription: 'Mock File Description',
      legalCopyright: '© 2026 Mock Company',
      originalFilename: 'mock.exe',
      companyName: 'Mock Company',
    );
  }
}

void main() {
  final FlutterBinPlatform initialPlatform = FlutterBinPlatform.instance;

  test('default instance is platform-appropriate', () {
    if (Platform.isWindows) {
      expect(initialPlatform, isA<FlutterBinFfiWindows>());
    } else if (Platform.isMacOS) {
      expect(initialPlatform, isA<FlutterBinMacOS>());
    } else {
      expect(initialPlatform, isA<UnsupportedFlutterBin>());
    }
  });

  test('getBinaryFileVersion delegates to the active platform', () async {
    final flutterBinPlugin = FlutterBin();
    FlutterBinPlatform.instance = MockFlutterBinPlatform();

    expect(await flutterBinPlugin.getBinaryFileVersion('test.exe'), '1.2.3.4');
  });

  test('getBinaryFileMetadata delegates to the active platform', () async {
    final flutterBinPlugin = FlutterBin();
    FlutterBinPlatform.instance = MockFlutterBinPlatform();

    final metadata = await flutterBinPlugin.getBinaryFileMetadata('test.exe');
    expect(metadata.version, '1.2.3.4');
    expect(metadata.productName, 'Mock Product');
    expect(metadata.fileDescription, 'Mock File Description');
    expect(metadata.legalCopyright, '© 2026 Mock Company');
    expect(metadata.originalFilename, 'mock.exe');
    expect(metadata.companyName, 'Mock Company');
  });

  test('UnsupportedFlutterBin surfaces UnsupportedError via the Future',
      () async {
    // Exercised through the returned Future (as a real caller would await it),
    // not a synchronous closure — the error must arrive as a Future rejection.
    final platform = UnsupportedFlutterBin();
    await expectLater(
        platform.getBinaryFileVersion('x'), throwsUnsupportedError);
    await expectLater(
        platform.getBinaryFileMetadata('x'), throwsUnsupportedError);
  });
}

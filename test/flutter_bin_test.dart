import 'dart:io' show Platform;

import 'package:flutter_bin/flutter_bin.dart';
import 'package:flutter_bin/flutter_bin_method_channel.dart';
import 'package:flutter_bin/flutter_bin_platform_interface.dart';
import 'package:flutter_bin/src/macos/flutter_bin_macos.dart';
import 'package:flutter_bin/src/windows/flutter_bin_ffi_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBinPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBinPlatform {
  @override
  Future<String?> getBinaryFileVersion(String filePath) async {
    return '1.2.3.4';
  }

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) async {
    return BinaryFileMetadata(
      version: '1.2.3.4',
      productName: 'Mock Product',
      fileDescription: 'Mock File Description',
      legalCopyright: '© 2025 Mock Company',
      originalFilename: 'mock.exe',
      companyName: 'Mock Company',
    );
  }
}

void main() {
  final FlutterBinPlatform initialPlatform = FlutterBinPlatform.instance;

  test('default instance is platform-appropriate', () {
    if (Platform.isWindows) {
      expect(initialPlatform, isInstanceOf<FlutterBinFfiWindows>());
    } else if (Platform.isMacOS) {
      expect(initialPlatform, isInstanceOf<FlutterBinMacOS>());
    } else {
      expect(initialPlatform, isInstanceOf<MethodChannelFlutterBin>());
    }
  });

  test('getBinaryFileVersion', () async {
    FlutterBin flutterBinPlugin = FlutterBin();
    MockFlutterBinPlatform fakePlatform = MockFlutterBinPlatform();
    FlutterBinPlatform.instance = fakePlatform;

    expect(await flutterBinPlugin.getBinaryFileVersion('test.exe'), '1.2.3.4');
  });

  test('getBinaryFileMetadata', () async {
    FlutterBin flutterBinPlugin = FlutterBin();
    MockFlutterBinPlatform fakePlatform = MockFlutterBinPlatform();
    FlutterBinPlatform.instance = fakePlatform;

    final metadata = await flutterBinPlugin.getBinaryFileMetadata('test.exe');

    expect(metadata.version, '1.2.3.4');
    expect(metadata.productName, 'Mock Product');
    expect(metadata.fileDescription, 'Mock File Description');
    expect(metadata.legalCopyright, '© 2025 Mock Company');
    expect(metadata.originalFilename, 'mock.exe');
    expect(metadata.companyName, 'Mock Company');
  });
}

import 'dart:io';

import 'package:flutter_bin/src/macos/flutter_bin_macos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Builds a throwaway `App.app/Contents/Info.plist` bundle from a fixture and
  // returns the bundle-root path. Platform-independent: exercises resolution +
  // file read + plist parse together, so it runs on the Windows dev host too.
  String bundleFrom(String fixture) {
    final tmp = Directory.systemTemp.createTempSync('flutter_bin_macos');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final bundle = '${tmp.path}/App.app';
    Directory('$bundle/Contents').createSync(recursive: true);
    File('$bundle/Contents/Info.plist').writeAsBytesSync(
        File('test/macos/fixtures/$fixture').readAsBytesSync());
    return bundle;
  }

  final plugin = FlutterBinMacOS();

  for (final fixture in ['full_binary.plist', 'full_xml.plist']) {
    test('reads full metadata from $fixture', () async {
      final bundle = bundleFrom(fixture);

      expect(await plugin.getBinaryFileVersion(bundle), '1.2.3');

      final md = await plugin.getBinaryFileMetadata(bundle);
      expect(md.version, '1.2.3');
      expect(md.productName, 'Test Product');
      expect(md.fileDescription, 'Test File Description');
      expect(md.legalCopyright, '© 2026 Test Company');
      expect(md.originalFilename, 'test');
      expect(md.companyName, ''); // never populated on macOS
    });
  }

  test('absent string fields default to empty strings', () async {
    final bundle = bundleFrom('partial_xml.plist');

    expect(await plugin.getBinaryFileVersion(bundle), '9.9');

    final md = await plugin.getBinaryFileMetadata(bundle);
    expect(md.version, '9.9');
    expect(md.productName, 'Partial Product');
    expect(md.fileDescription, '');
    expect(md.legalCopyright, '');
    expect(md.originalFilename, '');
    expect(md.companyName, '');
  });

  test('an already-resolved Contents/Info.plist path still reads', () async {
    final bundle = bundleFrom('full_binary.plist');

    final version =
        await plugin.getBinaryFileVersion('$bundle/Contents/Info.plist');
    expect(version, '1.2.3');
  });

  // Writes raw [bytes] as the bundle's Info.plist and returns the bundle root.
  String bundleFromBytes(List<int> bytes) {
    final tmp = Directory.systemTemp.createTempSync('flutter_bin_macos');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final bundle = '${tmp.path}/App.app';
    Directory('$bundle/Contents').createSync(recursive: true);
    File('$bundle/Contents/Info.plist').writeAsBytesSync(bytes);
    return bundle;
  }

  test('a corrupt binary plist yields null version and empty metadata',
      () async {
    // Valid bplist00 magic but garbage body -> parse throws -> null/empty.
    final bundle = bundleFromBytes(
        [...'bplist00'.codeUnits, 0xFF, 0x00, 0x13, 0x37, 0xDE, 0xAD]);

    expect(await plugin.getBinaryFileVersion(bundle), isNull);
    expect((await plugin.getBinaryFileMetadata(bundle)).version, '');
  });

  test('a malformed XML plist yields null version and empty metadata',
      () async {
    final bundle = bundleFromBytes(
        '<?xml version="1.0"?><plist><dict><key>oops'.codeUnits);

    expect(await plugin.getBinaryFileVersion(bundle), isNull);
    expect((await plugin.getBinaryFileMetadata(bundle)).version, '');
  });

  test('missing plist yields null version and empty metadata', () async {
    final tmp = Directory.systemTemp.createTempSync('flutter_bin_macos');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final bundle = '${tmp.path}/Empty.app'; // no Contents/Info.plist inside

    expect(await plugin.getBinaryFileVersion(bundle), isNull);

    final md = await plugin.getBinaryFileMetadata(bundle);
    expect(md.version, '');
    expect(md.productName, '');
    expect(md.companyName, '');
  });
}

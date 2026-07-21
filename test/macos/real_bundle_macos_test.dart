@TestOn('mac-os')
library;

import 'dart:io';

import 'package:flutter_bin/src/macos/flutter_bin_macos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test against a real system `.app` bundle. Runs only on macOS (a no-op
/// on the Windows/Linux CI jobs), so it exercises the real binary Info.plist a
/// shipped app carries.
void main() {
  final plugin = FlutterBinMacOS();

  test('reads version + metadata from a real system app bundle', () async {
    // Pick whichever stock app exists on the runner.
    const candidates = [
      '/System/Applications/Calculator.app',
      '/Applications/Safari.app',
      '/System/Applications/Utilities/Terminal.app',
    ];
    final bundle = candidates.firstWhere(
      (path) => Directory(path).existsSync(),
      orElse: () => '',
    );
    if (bundle.isEmpty) {
      markTestSkipped('no known system .app bundle present');
      return;
    }

    final version = await plugin.getBinaryFileVersion(bundle);
    expect(version, isNotNull);
    expect(version, isNotEmpty);

    final md = await plugin.getBinaryFileMetadata(bundle);
    expect(md.version, isNotEmpty);
    expect(md.productName, isNotEmpty);
    expect(md.originalFilename, isNotEmpty);
    expect(md.companyName, ''); // always empty on macOS
  });
}

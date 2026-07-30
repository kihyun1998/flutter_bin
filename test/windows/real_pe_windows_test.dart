@TestOn('windows')
library;

import 'dart:io';

import 'package:flutter_bin/pe.dart';
import 'package:flutter_bin/src/windows/version_reader.dart';
import 'package:test/test.dart';

/// Smoke tests against real binaries a Windows host ships, so the parser is
/// exercised against resources produced by a real toolchain rather than the
/// synthetic fixtures. A no-op on the Linux/macOS CI jobs.
void main() {
  final system32 = r'C:\Windows\System32';

  test('reads a real system binary', () async {
    const candidates = ['notepad.exe', 'mstsc.exe', 'cmd.exe'];
    final path = candidates
        .map((name) => '$system32\\$name')
        .firstWhere((path) => File(path).existsSync(), orElse: () => '');
    if (path.isEmpty) {
      markTestSkipped('no known system binary present');
      return;
    }

    final resource = await readPeVersionResource(path);

    expect(resource, isNotNull);
    // Microsoft's toolchain stores the version resource under the numeric id.
    expect(resource!.resourceName, '#1');
    expect(resource.stringTables, isNotEmpty);
    expect(resource.fixedFileVersion, isNotEmpty);
    expect(resource.value('CompanyName'), contains('Microsoft'));
    expect(resource.toBinaryFileMetadata().version.split('.'), hasLength(3));
  });

  test('image view does not follow MUI satellite resources', () async {
    final path = '$system32\\mstsc.exe';
    if (!File(path).existsSync()) {
      markTestSkipped('mstsc.exe not present');
      return;
    }

    final image = await readPeVersionResource(path);
    final osView = WindowsVersionReader().readMetadata(path);

    // The image carries its own name; the OS reports the satellite resource file
    // when the binary is MUI-based, which is why the two views can disagree.
    expect(image!.value('OriginalFilename'), 'mstsc.exe');
    expect(
      osView['originalFilename'],
      anyOf('mstsc.exe.mui', 'mstsc.exe'),
    );
  });
}

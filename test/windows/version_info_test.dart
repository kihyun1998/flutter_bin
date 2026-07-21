import 'package:flutter_bin/src/windows/version_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatFixedVersion', () {
    test('composes major.minor.build from the two version DWORDs', () {
      // MS = major<<16 | minor, LS = build<<16 | revision.
      // 6.2.26100.8521 -> ms = (6<<16)|2, ls = (26100<<16)|8521
      final ms = (6 << 16) | 2;
      final ls = (26100 << 16) | 8521;
      expect(formatFixedVersion(ms, ls), '6.2.26100');
    });

    test('drops the 4th (revision) component per ADR-0003', () {
      final ms = (1 << 16) | 2;
      final ls = (3 << 16) | 4;
      expect(formatFixedVersion(ms, ls), '1.2.3');
    });

    test('handles zeros', () {
      expect(formatFixedVersion(0, 0), '0.0.0');
    });

    test('handles the max 16-bit field value', () {
      final ms = (0xFFFF << 16) | 0xFFFF;
      final ls = (0xFFFF << 16) | 0x0000;
      expect(formatFixedVersion(ms, ls), '65535.65535.65535');
    });
  });

  group('stringFileInfoSubBlock', () {
    test('default block uses the hardcoded uppercase 040904B0 lang/codepage',
        () {
      expect(
        stringFileInfoSubBlock(key: 'ProductName'),
        r'\StringFileInfo\040904B0\ProductName',
      );
    });

    test(
        'translated block formats language + codepage as 4-digit lowercase hex',
        () {
      // Korean (0x0412) + Unicode codepage (0x04B0 = 1200).
      expect(
        stringFileInfoSubBlock(
          key: 'CompanyName',
          language: 0x0412,
          codePage: 0x04B0,
        ),
        r'\StringFileInfo\041204b0\CompanyName',
      );
    });

    test('pads short language/codepage values to 4 hex digits', () {
      expect(
        stringFileInfoSubBlock(
            key: 'FileDescription', language: 0x9, codePage: 0x1),
        r'\StringFileInfo\00090001\FileDescription',
      );
    });
  });
}

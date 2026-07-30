import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bin/pe.dart';
import 'package:test/test.dart';

import 'pe_fixture_builder.dart';

void main() {
  group('parsePeVersionResource', () {
    test('reads a resource named "VS_VERSION_INFO" instead of id 1', () {
      // The FileZilla 3.66.5 shape: windres emitted the version resource under a
      // name string, so the Win32 version APIs — which look up the numeric id 1
      // only — report the file as having no version info at all.
      final image = buildPeImage(resourceName: 'VS_VERSION_INFO');

      final resource = parsePeVersionResource(image);

      expect(resource, isNotNull);
      expect(resource!.resourceName, 'VS_VERSION_INFO');
      expect(resource.languageId, 1033);
      expect(resource.fixedFileVersion, '3.66.5.0');
      expect(resource.fixedProductVersion, '3.66.5.0');
      expect(resource.stringTables, hasLength(1));

      final table = resource.stringTables.single;
      expect(table.languageCodePage, '000004b0');
      expect(table.values, hasLength(9));
      expect(table.values['CompanyName'], 'FileZilla Project');
      expect(table.values['ProductName'], 'FileZilla');
      expect(table.values['OriginalFilename'], 'filezilla.exe');
      expect(table.values['Comments'], 'Version 3.66.5');
      expect(table.values['FileDescription'], 'FileZilla FTP Client');
      expect(table.values['FileVersion'], '3, 66, 5, 0');
      expect(table.values['InternalName'], 'FileZilla 3');
      expect(table.values['LegalCopyright'], 'Copyright (C) 2006-2024');
      expect(table.values['ProductVersion'], '3, 66, 5, 0');
    });

    test('reads the conventional numeric resource id', () {
      final resource = parsePeVersionResource(buildPeImage(resourceName: 1));

      expect(resource, isNotNull);
      expect(resource!.resourceName, '#1');
      expect(resource.value('ProductName'), 'FileZilla');
    });

    test('reads a 32-bit (PE32) image', () {
      final resource = parsePeVersionResource(buildPeImage(pe32Plus: false));

      expect(resource, isNotNull);
      expect(resource!.fixedFileVersion, '3.66.5.0');
      expect(resource.value('CompanyName'), 'FileZilla Project');
    });

    test('keeps every string table, in file order', () {
      final resource = parsePeVersionResource(
        buildPeImage(
          tables: const [
            PeTableSpec('040904B0', {
              'ProductName': 'Remote Desktop Connection',
              'CompanyName': 'Microsoft Corporation',
            }),
            PeTableSpec('041204B0', {
              'ProductName': '원격 데스크톱 연결',
            }),
          ],
        ),
      );

      expect(resource, isNotNull);
      expect(
        resource!.stringTables.map((table) => table.languageCodePage),
        ['040904B0', '041204B0'],
      );
      // value() answers from the first table that has the key.
      expect(resource.value('ProductName'), 'Remote Desktop Connection');
      expect(resource.stringTables[1].values['ProductName'], '원격 데스크톱 연결');
      // Keys absent from the first table still resolve from a later one.
      expect(resource.value('CompanyName'), 'Microsoft Corporation');
    });

    test('reports the resource language id', () {
      final resource = parsePeVersionResource(buildPeImage(languageId: 1042));

      expect(resource!.languageId, 1042);
    });

    test('omits fixed versions when the resource carries no VS_FIXEDFILEINFO',
        () {
      final resource = parsePeVersionResource(buildPeImage(fileVersion: null));

      expect(resource, isNotNull);
      expect(resource!.fixedFileVersion, '');
      expect(resource.fixedProductVersion, '');
      // The string tables are independent of the fixed info and still parse.
      expect(resource.value('ProductName'), 'FileZilla');
    });

    test('returns a resource with no tables when only fixed info is present',
        () {
      final resource = parsePeVersionResource(buildPeImage(tables: const []));

      expect(resource, isNotNull);
      expect(resource!.fixedFileVersion, '3.66.5.0');
      expect(resource.stringTables, isEmpty);
      expect(resource.value('ProductName'), isNull);
    });

    test('reports file and product versions independently', () {
      final resource = parsePeVersionResource(
        buildPeImage(
          fileVersion: const [10, 0, 26100, 8875],
          productVersion: const [10, 0, 26100, 1],
        ),
      );

      expect(resource!.fixedFileVersion, '10.0.26100.8875');
      expect(resource.fixedProductVersion, '10.0.26100.1');
    });

    group('returns null instead of throwing', () {
      test('for an empty buffer', () {
        expect(parsePeVersionResource(Uint8List(0)), isNull);
      });

      test('for bytes that are not a PE image', () {
        expect(
          parsePeVersionResource(Uint8List.fromList(List.filled(4096, 0x41))),
          isNull,
        );
      });

      test('when the image has no resource section', () {
        expect(
          parsePeVersionResource(buildPeImage(includeResourceSection: false)),
          isNull,
        );
      });

      test('when the resource directory holds no RT_VERSION type', () {
        // Type 24 = RT_MANIFEST, which every real binary also carries.
        expect(
          parsePeVersionResource(buildPeImage(resourceTypeId: 24)),
          isNull,
        );
      });

      test('when the file is truncated mid-resource', () {
        final image = buildPeImage();
        expect(
          parsePeVersionResource(
            Uint8List.sublistView(image, 0, image.length - 400),
          ),
          isNull,
        );
      });

      test('when the data entry claims a size past the end of the file', () {
        expect(
          parsePeVersionResource(
            buildPeImage(dataEntrySizeOverride: 0x100000),
          ),
          isNull,
        );
      });

      test('when the data entry claims an empty resource', () {
        expect(parsePeVersionResource(buildPeImage(dataEntrySizeOverride: 0)),
            isNull);
      });
    });

    test('survives a root node whose wLength runs past the block', () {
      // A corrupt length must not read beyond the resource or throw; whatever is
      // parseable before the overrun is fair game.
      final resource =
          parsePeVersionResource(buildPeImage(rootLengthOverride: 0xFFFF));

      expect(resource, isNotNull);
      expect(resource!.fixedFileVersion, '3.66.5.0');
    });
  });

  group('PeVersionResource', () {
    test('value() returns null for a key no table carries', () {
      final resource = parsePeVersionResource(buildPeImage())!;

      expect(resource.value('PrivateBuild'), isNull);
    });

    test('toBinaryFileMetadata() maps onto the existing model', () {
      final metadata =
          parsePeVersionResource(buildPeImage())!.toBinaryFileMetadata();

      // Version is truncated to major.minor.build per ADR-0003.
      expect(metadata.version, '3.66.5');
      expect(metadata.companyName, 'FileZilla Project');
      expect(metadata.productName, 'FileZilla');
      expect(metadata.originalFilename, 'filezilla.exe');
      expect(metadata.fileDescription, 'FileZilla FTP Client');
      expect(metadata.legalCopyright, 'Copyright (C) 2006-2024');
    });

    test('toBinaryFileMetadata() defaults absent fields to empty strings', () {
      final metadata = parsePeVersionResource(
        buildPeImage(
          fileVersion: null,
          tables: const [
            PeTableSpec('040904B0', {'ProductName': 'Minimal'}),
          ],
        ),
      )!
          .toBinaryFileMetadata();

      expect(metadata.productName, 'Minimal');
      expect(metadata.version, '');
      expect(metadata.companyName, '');
      expect(metadata.originalFilename, '');
      expect(metadata.fileDescription, '');
      expect(metadata.legalCopyright, '');
    });
  });

  group('readPeVersionResource', () {
    late Directory tempDir;

    setUp(
        () => tempDir = Directory.systemTemp.createTempSync('flutter_bin_pe'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    File write(String name, Uint8List bytes) =>
        File('${tempDir.path}${Platform.pathSeparator}$name')
          ..writeAsBytesSync(bytes);

    test('reads a file from disk on any host platform', () async {
      final file =
          write('named.exe', buildPeImage(resourceName: 'VS_VERSION_INFO'));

      final resource = await readPeVersionResource(file.path);

      expect(resource, isNotNull);
      expect(resource!.resourceName, 'VS_VERSION_INFO');
      expect(resource.value('ProductName'), 'FileZilla');
    });

    test('returns null for a path that does not exist', () async {
      expect(
        await readPeVersionResource('${tempDir.path}/absent.exe'),
        isNull,
      );
    });

    test('returns null for a directory', () async {
      expect(await readPeVersionResource(tempDir.path), isNull);
    });

    test('returns null for a file that is not a PE image', () async {
      final file = write('notes.txt', Uint8List.fromList('hello'.codeUnits));

      expect(await readPeVersionResource(file.path), isNull);
    });
  });
}

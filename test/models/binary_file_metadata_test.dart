import 'package:flutter_bin/flutter_bin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The canonical method-channel metadata key contract. The native
  // implementations (Windows C++, macOS Swift) must emit exactly these keys,
  // and `BinaryFileMetadataJsonKey` is the single source of truth for them.
  // This literal list is written independently of the enum so a drift on
  // either side fails the test rather than passing by construction.
  const canonicalKeys = <String>[
    'version',
    'productName',
    'fileDescription',
    'legalCopyright',
    'originalFilename',
    'companyName',
  ];

  test('BinaryFileMetadataJsonKey defines exactly the canonical channel keys',
      () {
    expect(
      BinaryFileMetadataJsonKey.values.map((e) => e.key).toList(),
      canonicalKeys,
    );
  });

  test('fromJson maps every canonical key onto its field', () {
    final json = {for (final key in canonicalKeys) key: 'val_$key'};
    final metadata = BinaryFileMetadata.fromJson(json);

    expect(metadata.version, 'val_version');
    expect(metadata.productName, 'val_productName');
    expect(metadata.fileDescription, 'val_fileDescription');
    expect(metadata.legalCopyright, 'val_legalCopyright');
    expect(metadata.originalFilename, 'val_originalFilename');
    expect(metadata.companyName, 'val_companyName');
  });

  test('fromJson defaults missing keys to empty strings', () {
    final metadata = BinaryFileMetadata.fromJson({});

    expect(metadata.version, '');
    expect(metadata.companyName, '');
  });
}

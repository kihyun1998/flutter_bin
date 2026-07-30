/// Builds minimal PE images carrying a version resource, so the reader can be
/// tested without shipping vendor binaries.
///
/// The images are structurally valid where the reader looks (DOS stub, COFF and
/// optional headers, one `.rsrc` section, a three-level resource directory and a
/// `VS_VERSIONINFO` tree) and zero-filled everywhere else — they are not
/// loadable executables.
library;

import 'dart:typed_data';

/// How the `RT_VERSION` entry is named in the resource directory.
///
/// The distinction is the point of these fixtures: the Win32 version APIs find
/// [PeResourceId] entries only, so [PeResourceName] ones read as having no
/// version info at all.
sealed class PeResourceKey {
  const PeResourceKey();
}

/// A numeric entry, e.g. the conventional `1`.
final class PeResourceId extends PeResourceKey {
  const PeResourceId(this.value);

  final int value;
}

/// A name-string entry, e.g. `VS_VERSION_INFO`.
final class PeResourceName extends PeResourceKey {
  const PeResourceName(this.value);

  final String value;
}

/// One `StringFileInfo` table to emit.
class PeTableSpec {
  const PeTableSpec(this.languageCodePage, this.values);

  final String languageCodePage;
  final Map<String, String> values;
}

/// The nine keys FileZilla 3.66.5 carries, under its language-neutral table.
const List<PeTableSpec> fileZillaTables = [
  PeTableSpec('000004b0', {
    'Comments': 'Version 3.66.5',
    'CompanyName': 'FileZilla Project',
    'FileDescription': 'FileZilla FTP Client',
    'FileVersion': '3, 66, 5, 0',
    'InternalName': 'FileZilla 3',
    'LegalCopyright': 'Copyright (C) 2006-2024',
    'OriginalFilename': 'filezilla.exe',
    'ProductName': 'FileZilla',
    'ProductVersion': '3, 66, 5, 0',
  }),
];

/// One `RT_VERSION` leaf to emit: how its directory entry is named, which
/// language it sits under, and what payload it carries.
class PeLeafSpec {
  const PeLeafSpec({
    this.resourceKey = const PeResourceId(1),
    this.languageId = 1033,
    this.fileVersion = const [3, 66, 5, 0],
    this.productVersion,
    this.tables = fileZillaTables,
    this.dataEntrySizeOverride,
  });

  final PeResourceKey resourceKey;
  final int languageId;
  final List<int>? fileVersion;
  final List<int>? productVersion;
  final List<PeTableSpec> tables;

  /// Makes this leaf's data entry lie about its payload size, so a single
  /// unusable leaf can be placed among healthy ones.
  final int? dataEntrySizeOverride;
}

const int _rsrcRva = 0x1000;
const int _fileAlignment = 0x200;

/// Builds a PE image whose `.rsrc` section holds one version resource.
///
/// [resourceKey] names the `RT_VERSION` entry — [PeResourceId] for the
/// conventional numeric id, [PeResourceName] for the string-named case this
/// package exists to read. [resourceTypeId] defaults to `RT_VERSION`; pass
/// another id to build an image with no version resource at all. A null
/// [fileVersion] omits `VS_FIXEDFILEINFO`. [rootLengthOverride] corrupts the root
/// node's `wLength`, and [dataEntrySizeOverride] lies about the resource size, so
/// the reader's bounds handling can be exercised.
Uint8List buildPeImage({
  PeResourceKey resourceKey = const PeResourceId(1),
  int resourceTypeId = 16,
  int languageId = 1033,
  bool pe32Plus = true,
  List<int>? fileVersion = const [3, 66, 5, 0],
  List<int>? productVersion,
  List<PeTableSpec> tables = fileZillaTables,
  bool includeResourceSection = true,
  int? rootLengthOverride,
  int? dataEntrySizeOverride,
}) {
  return buildPeImageWithLeaves(
    leaves: [
      PeLeafSpec(
        resourceKey: resourceKey,
        languageId: languageId,
        fileVersion: fileVersion,
        productVersion: productVersion,
        tables: tables,
      ),
    ],
    resourceTypeId: resourceTypeId,
    pe32Plus: pe32Plus,
    includeResourceSection: includeResourceSection,
    rootLengthOverride: rootLengthOverride,
    dataEntrySizeOverride: dataEntrySizeOverride,
  );
}

/// Builds a PE image carrying several `RT_VERSION` leaves — a name entry per
/// distinct [PeLeafSpec.resourceKey], and a language entry under it per leaf that
/// shares that key. This is the multi-language / multi-name shape the single-leaf
/// [buildPeImage] cannot express.
///
/// [rootLengthOverride] and [dataEntrySizeOverride] apply to every leaf; use
/// [PeLeafSpec.dataEntrySizeOverride] to corrupt one leaf in isolation.
Uint8List buildPeImageWithLeaves({
  required List<PeLeafSpec> leaves,
  int resourceTypeId = 16,
  bool pe32Plus = true,
  bool includeResourceSection = true,
  int? rootLengthOverride,
  int? dataEntrySizeOverride,
}) {
  final rsrc = includeResourceSection
      ? _buildResourceSection(
          leaves: leaves,
          resourceTypeId: resourceTypeId,
          rootLengthOverride: rootLengthOverride,
          dataEntrySizeOverride: dataEntrySizeOverride,
        )
      : Uint8List(0);

  return _buildImage(rsrc: rsrc, pe32Plus: pe32Plus);
}

/// Builds a bare `VS_VERSIONINFO` tree — the payload a version resource holds.
Uint8List buildVersionBlock({
  List<int>? fileVersion = const [3, 66, 5, 0],
  List<int>? productVersion = const [3, 66, 5, 0],
  List<PeTableSpec> tables = fileZillaTables,
  int? rootLengthOverride,
}) {
  final children = <Uint8List>[];

  if (tables.isNotEmpty) {
    children.add(
      _node(
        key: 'StringFileInfo',
        textValue: true,
        children: [
          for (final table in tables)
            _node(
              key: table.languageCodePage,
              textValue: true,
              children: [
                for (final entry in table.values.entries)
                  _node(
                    key: entry.key,
                    textValue: true,
                    value: _utf16z(entry.value),
                  ),
              ],
            ),
        ],
      ),
    );
    // A real image also advertises its translations; the reader ignores this
    // block, and including it proves that it does.
    children.add(
      _node(
        key: 'VarFileInfo',
        textValue: true,
        children: [
          _node(
            key: 'Translation',
            textValue: false,
            value: _translationValue(tables),
          ),
        ],
      ),
    );
  }

  return _node(
    key: 'VS_VERSION_INFO',
    textValue: false,
    value: fileVersion == null
        ? null
        : _fixedFileInfo(fileVersion, productVersion ?? fileVersion),
    children: children,
    lengthOverride: rootLengthOverride,
  );
}

// --- VS_VERSIONINFO nodes ---------------------------------------------------

/// One `{wLength, wValueLength, wType, szKey, padding, Value, padding, Children}`
/// node. `wLength` covers the node and its children but not trailing padding,
/// and `wValueLength` counts 16-bit words for text values, bytes for binary.
Uint8List _node({
  required String key,
  required bool textValue,
  Uint8List? value,
  List<Uint8List> children = const [],
  int? lengthOverride,
}) {
  final body = BytesBuilder();
  body.add(_utf16z(key));
  _padTo4(body, 6 + body.length);
  if (value != null) {
    body.add(value);
    _padTo4(body, 6 + body.length);
  }
  for (var i = 0; i < children.length; i++) {
    body.add(children[i]);
    if (i != children.length - 1) _padTo4(body, 6 + body.length);
  }

  final bodyBytes = body.toBytes();
  final valueLength =
      value == null ? 0 : (textValue ? value.length ~/ 2 : value.length);

  final out = Uint8List(6 + bodyBytes.length);
  final view = ByteData.sublistView(out);
  view.setUint16(0, lengthOverride ?? out.length, Endian.little);
  view.setUint16(2, valueLength, Endian.little);
  view.setUint16(4, textValue ? 1 : 0, Endian.little);
  out.setRange(6, out.length, bodyBytes);
  return out;
}

/// `VS_FIXEDFILEINFO` — 13 DWORDs.
Uint8List _fixedFileInfo(List<int> fileVersion, List<int> productVersion) {
  final out = Uint8List(52);
  final view = ByteData.sublistView(out);
  int ms(List<int> v) => (v[0] << 16) | v[1];
  int ls(List<int> v) => (v[2] << 16) | v[3];
  view.setUint32(0, 0xFEEF04BD, Endian.little); // dwSignature
  view.setUint32(4, 0x00010000, Endian.little); // dwStrucVersion
  view.setUint32(8, ms(fileVersion), Endian.little);
  view.setUint32(12, ls(fileVersion), Endian.little);
  view.setUint32(16, ms(productVersion), Endian.little);
  view.setUint32(20, ls(productVersion), Endian.little);
  view.setUint32(24, 0x3F, Endian.little); // dwFileFlagsMask
  view.setUint32(32, 0x00040004, Endian.little); // dwFileOS = NT/Windows32
  view.setUint32(36, 1, Endian.little); // dwFileType = VFT_APP
  return out;
}

Uint8List _translationValue(List<PeTableSpec> tables) {
  final out = Uint8List(tables.length * 4);
  final view = ByteData.sublistView(out);
  for (var i = 0; i < tables.length; i++) {
    final langCp = tables[i].languageCodePage;
    view.setUint16(
        i * 4, int.parse(langCp.substring(0, 4), radix: 16), Endian.little);
    view.setUint16(
        i * 4 + 2, int.parse(langCp.substring(4, 8), radix: 16), Endian.little);
  }
  return out;
}

// --- resource directory ----------------------------------------------------

/// Three levels of `IMAGE_RESOURCE_DIRECTORY` (type -> name -> language), one
/// `IMAGE_RESOURCE_DATA_ENTRY` per leaf, the name strings, then the payloads.
Uint8List _buildResourceSection({
  required List<PeLeafSpec> leaves,
  required int resourceTypeId,
  int? rootLengthOverride,
  int? dataEntrySizeOverride,
}) {
  // A name entry per distinct key, with its leaves beneath it. PE sorts named
  // entries before id entries, so emit them in that order.
  final groups = <String, List<PeLeafSpec>>{};
  for (final leaf in leaves) {
    groups.putIfAbsent(_groupKey(leaf.resourceKey), () => []).add(leaf);
  }
  final ordered = [
    ...groups.values
        .where((group) => group.first.resourceKey is PeResourceName),
    ...groups.values.where((group) => group.first.resourceKey is PeResourceId),
  ];

  const dirHeader = 16;
  const entrySize = 8;
  const dataEntrySize = 16;

  // Lay the section out in one pass: directories, data entries, name strings,
  // then the 4-byte-aligned payloads.
  var cursor = 0;
  final typeDirOffset = cursor;
  cursor += dirHeader + entrySize;
  final nameDirOffset = cursor;
  cursor += dirHeader + entrySize * ordered.length;

  final languageDirOffsets = <int>[];
  for (final group in ordered) {
    languageDirOffsets.add(cursor);
    cursor += dirHeader + entrySize * group.length;
  }

  final dataEntryOffsets = <List<int>>[];
  for (final group in ordered) {
    final offsets = <int>[];
    for (var i = 0; i < group.length; i++) {
      offsets.add(cursor);
      cursor += dataEntrySize;
    }
    dataEntryOffsets.add(offsets);
  }

  final nameStrings = <Uint8List?>[];
  final nameStringOffsets = <int>[];
  for (final group in ordered) {
    final key = group.first.resourceKey;
    final string = switch (key) {
      PeResourceId() => null,
      PeResourceName(:final value) => _resourceNameString(value),
    };
    nameStrings.add(string);
    nameStringOffsets.add(cursor);
    cursor += string?.length ?? 0;
  }

  final payloads = <List<Uint8List>>[];
  final payloadOffsets = <List<int>>[];
  for (final group in ordered) {
    final blocks = <Uint8List>[];
    final offsets = <int>[];
    for (final leaf in group) {
      cursor = _align4(cursor);
      offsets.add(cursor);
      final block = buildVersionBlock(
        fileVersion: leaf.fileVersion,
        productVersion: leaf.productVersion ?? leaf.fileVersion,
        tables: leaf.tables,
        rootLengthOverride: rootLengthOverride,
      );
      blocks.add(block);
      cursor += block.length;
    }
    payloads.add(blocks);
    payloadOffsets.add(offsets);
  }

  final out = Uint8List(cursor);
  final view = ByteData.sublistView(out);

  void writeDirectoryHeader(int offset, int namedCount, int idCount) {
    view.setUint16(offset + 12, namedCount, Endian.little);
    view.setUint16(offset + 14, idCount, Endian.little);
  }

  void writeEntry(int offset, int nameField, int childOffset,
      {required bool isLeafPointer}) {
    view.setUint32(offset, nameField, Endian.little);
    view.setUint32(
      offset + 4,
      isLeafPointer ? childOffset : (0x80000000 | childOffset),
      Endian.little,
    );
  }

  writeDirectoryHeader(typeDirOffset, 0, 1);
  writeEntry(typeDirOffset + dirHeader, resourceTypeId, nameDirOffset,
      isLeafPointer: false);

  final namedGroups = nameStrings.where((string) => string != null).length;
  writeDirectoryHeader(
      nameDirOffset, namedGroups, ordered.length - namedGroups);

  for (var g = 0; g < ordered.length; g++) {
    final group = ordered[g];
    final nameString = nameStrings[g];
    writeEntry(
      nameDirOffset + dirHeader + entrySize * g,
      switch (group.first.resourceKey) {
        PeResourceId(:final value) => value,
        PeResourceName() => 0x80000000 | nameStringOffsets[g],
      },
      languageDirOffsets[g],
      isLeafPointer: false,
    );
    if (nameString != null) {
      out.setRange(nameStringOffsets[g],
          nameStringOffsets[g] + nameString.length, nameString);
    }

    writeDirectoryHeader(languageDirOffsets[g], 0, group.length);
    for (var l = 0; l < group.length; l++) {
      writeEntry(
        languageDirOffsets[g] + dirHeader + entrySize * l,
        group[l].languageId,
        dataEntryOffsets[g][l],
        isLeafPointer: true,
      );

      final payload = payloads[g][l];
      final payloadOffset = payloadOffsets[g][l];
      view.setUint32(
          dataEntryOffsets[g][l], _rsrcRva + payloadOffset, Endian.little);
      view.setUint32(
          dataEntryOffsets[g][l] + 4,
          group[l].dataEntrySizeOverride ??
              dataEntrySizeOverride ??
              payload.length,
          Endian.little);
      out.setRange(payloadOffset, payloadOffset + payload.length, payload);
    }
  }

  return out;
}

/// Groups leaves that share a directory entry — same id, or same name string.
String _groupKey(PeResourceKey key) => switch (key) {
      PeResourceId(:final value) => 'id:$value',
      PeResourceName(:final value) => 'name:$value',
    };

/// A resource directory name: 16-bit character count then the UTF-16 chars, no
/// terminator.
Uint8List _resourceNameString(String name) {
  final out = Uint8List(2 + name.length * 2);
  final view = ByteData.sublistView(out);
  view.setUint16(0, name.length, Endian.little);
  for (var i = 0; i < name.length; i++) {
    view.setUint16(2 + i * 2, name.codeUnitAt(i), Endian.little);
  }
  return out;
}

// --- PE headers ------------------------------------------------------------

Uint8List _buildImage({required Uint8List rsrc, required bool pe32Plus}) {
  const lfanew = 0x40;
  final optionalSize = pe32Plus ? 240 : 224;
  final dataDirOffset = pe32Plus ? 112 : 96;
  final sectionTableOffset = lfanew + 24 + optionalSize;
  final rawOffset = _alignTo(sectionTableOffset + 40, _fileAlignment);
  final rawSize = _alignTo(rsrc.length, _fileAlignment);

  final out = Uint8List(rawOffset + rawSize);
  final view = ByteData.sublistView(out);

  out[0] = 0x4D; // 'M'
  out[1] = 0x5A; // 'Z'
  view.setUint32(0x3C, lfanew, Endian.little);

  view.setUint32(lfanew, 0x00004550, Endian.little); // 'PE\0\0'
  final coff = lfanew + 4;
  view.setUint16(coff, pe32Plus ? 0x8664 : 0x014C, Endian.little); // machine
  view.setUint16(coff + 2, rsrc.isEmpty ? 0 : 1, Endian.little); // sections
  view.setUint16(coff + 16, optionalSize, Endian.little);
  view.setUint16(coff + 18, 0x0022, Endian.little); // characteristics

  final opt = coff + 20;
  view.setUint16(opt, pe32Plus ? 0x020B : 0x010B, Endian.little); // magic
  view.setUint32(opt + (pe32Plus ? 108 : 92), 16, Endian.little); // dir count
  if (rsrc.isNotEmpty) {
    // Data directory entry #2 = resource table.
    view.setUint32(opt + dataDirOffset + 16, _rsrcRva, Endian.little);
    view.setUint32(opt + dataDirOffset + 20, rsrc.length, Endian.little);

    const name = '.rsrc';
    for (var i = 0; i < name.length; i++) {
      out[sectionTableOffset + i] = name.codeUnitAt(i);
    }
    view.setUint32(sectionTableOffset + 8, rsrc.length, Endian.little);
    view.setUint32(sectionTableOffset + 12, _rsrcRva, Endian.little);
    view.setUint32(sectionTableOffset + 16, rawSize, Endian.little);
    view.setUint32(sectionTableOffset + 20, rawOffset, Endian.little);
    view.setUint32(sectionTableOffset + 36, 0x40000040, Endian.little);

    out.setRange(rawOffset, rawOffset + rsrc.length, rsrc);
  }

  return out;
}

// --- helpers ---------------------------------------------------------------

int _align4(int value) => (value + 3) & ~3;

int _alignTo(int value, int alignment) =>
    ((value + alignment - 1) ~/ alignment) * alignment;

void _padTo4(BytesBuilder builder, int absoluteLength) {
  final padding = _align4(absoluteLength) - absoluteLength;
  for (var i = 0; i < padding; i++) {
    builder.addByte(0);
  }
}

Uint8List _utf16z(String value) {
  final out = Uint8List((value.length + 1) * 2);
  final view = ByteData.sublistView(out);
  for (var i = 0; i < value.length; i++) {
    view.setUint16(i * 2, value.codeUnitAt(i), Endian.little);
  }
  return out;
}

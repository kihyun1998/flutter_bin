import 'dart:io';
import 'dart:typed_data';

import '../../models/pe_version_resource.dart';

/// Reads the version resource out of a PE image, in pure Dart.
///
/// Unlike the `version.dll` reader this needs no FFI and no Windows host — a PE
/// file can be inspected from any platform — and it finds the resource by type
/// alone, so images whose `RT_VERSION` entry is stored under a name string
/// (`VS_VERSION_INFO`, emitted by some `windres` builds) are readable. The Win32
/// version APIs look up the numeric id `1` and report those files as carrying no
/// version info at all.
///
/// Returns null when [filePath] is absent, is not a PE image, or has no version
/// resource. Never throws for malformed input.
Future<PeVersionResource?> readPeVersionResource(String filePath) async {
  final file = File(filePath);
  try {
    if (!await file.exists()) return null;
    return parsePeVersionResource(await file.readAsBytes());
  } on FileSystemException {
    return null;
  }
}

/// Parses an in-memory PE image. See [readPeVersionResource].
PeVersionResource? parsePeVersionResource(Uint8List bytes) {
  try {
    return _parseImage(bytes);
  } on RangeError {
    // Defence in depth: every read below is bounds-checked, so reaching here
    // means a case was missed — still no throw for the caller.
    return null;
  }
}

// --- PE image --------------------------------------------------------------

const int _dosSignature = 0x5A4D; // 'MZ'
const int _peSignature = 0x00004550; // 'PE\0\0'
const int _pe32Magic = 0x010B;
const int _pe32PlusMagic = 0x020B;
const int _resourceTableDirectoryIndex = 2;
const int _rtVersion = 16;
const int _subdirectoryFlag = 0x80000000;
const int _fixedFileInfoSignature = 0xFEEF04BD;

PeVersionResource? _parseImage(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 0x40) return null;
  if (data.getUint16(0, Endian.little) != _dosSignature) return null;

  final peOffset = data.getUint32(0x3C, Endian.little);
  if (peOffset + 24 > bytes.length) return null;
  if (data.getUint32(peOffset, Endian.little) != _peSignature) return null;

  final sectionCount = data.getUint16(peOffset + 6, Endian.little);
  final optionalSize = data.getUint16(peOffset + 20, Endian.little);
  final optional = peOffset + 24;
  if (optional + optionalSize > bytes.length) return null;

  final magic = data.getUint16(optional, Endian.little);
  final int directoryOffset;
  final int directoryCountOffset;
  switch (magic) {
    case _pe32Magic:
      directoryOffset = 96;
      directoryCountOffset = 92;
    case _pe32PlusMagic:
      directoryOffset = 112;
      directoryCountOffset = 108;
    default:
      return null;
  }
  if (optional + directoryOffset + 8 * (_resourceTableDirectoryIndex + 1) >
      bytes.length) {
    return null;
  }
  final directoryCount =
      data.getUint32(optional + directoryCountOffset, Endian.little);
  if (directoryCount <= _resourceTableDirectoryIndex) return null;

  final entry = optional + directoryOffset + 8 * _resourceTableDirectoryIndex;
  final resourceRva = data.getUint32(entry, Endian.little);
  if (resourceRva == 0) return null;

  final sections =
      _readSections(data, optional + optionalSize, sectionCount, bytes.length);
  final resourceBase = _rvaToOffset(sections, resourceRva);
  if (resourceBase == null || resourceBase + 16 > bytes.length) return null;

  return _readVersionLeaf(bytes, data, sections, resourceBase);
}

/// [virtualAddress, virtualSize, rawOffset] per section.
List<List<int>> _readSections(
    ByteData data, int tableOffset, int count, int fileLength) {
  final sections = <List<int>>[];
  for (var i = 0; i < count; i++) {
    final offset = tableOffset + i * 40;
    if (offset + 40 > fileLength) break;
    sections.add([
      data.getUint32(offset + 12, Endian.little), // VirtualAddress
      data.getUint32(offset + 8, Endian.little), // VirtualSize
      data.getUint32(offset + 20, Endian.little), // PointerToRawData
    ]);
  }
  return sections;
}

int? _rvaToOffset(List<List<int>> sections, int rva) {
  for (final section in sections) {
    final start = section[0];
    final size = section[1] == 0 ? 1 : section[1];
    if (rva >= start && rva < start + size) return section[2] + (rva - start);
  }
  return null;
}

/// Walks type -> name -> language and parses the leaf the `RT_VERSION` type
/// points at. The name level accepts any entry, id or string — that is what
/// makes string-named resources readable.
PeVersionResource? _readVersionLeaf(
  Uint8List bytes,
  ByteData data,
  List<List<int>> sections,
  int resourceBase,
) {
  final typeEntry = _findEntry(data, resourceBase, resourceBase, bytes.length,
      wantId: _rtVersion);
  if (typeEntry == null || !typeEntry.isSubdirectory) return null;

  final nameEntry = _findEntry(
      data, resourceBase + typeEntry.offset, resourceBase, bytes.length);
  if (nameEntry == null || !nameEntry.isSubdirectory) return null;

  final languageEntry = _findEntry(
      data, resourceBase + nameEntry.offset, resourceBase, bytes.length);
  if (languageEntry == null || languageEntry.isSubdirectory) return null;

  final dataEntry = resourceBase + languageEntry.offset;
  if (dataEntry + 8 > bytes.length) return null;
  final payloadRva = data.getUint32(dataEntry, Endian.little);
  final payloadSize = data.getUint32(dataEntry + 4, Endian.little);
  final payloadOffset = _rvaToOffset(sections, payloadRva);
  if (payloadOffset == null || payloadSize < 6) return null;
  if (payloadOffset + payloadSize > bytes.length) return null;

  return _parseVersionBlock(
    data,
    payloadOffset,
    payloadSize,
    resourceName: nameEntry.name,
    languageId: languageEntry.id,
  );
}

class _ResourceEntry {
  _ResourceEntry({
    required this.name,
    required this.id,
    required this.offset,
    required this.isSubdirectory,
  });

  /// `#<id>` for numeric entries, the name string otherwise.
  final String name;
  final int id;
  final int offset;
  final bool isSubdirectory;
}

/// Returns the first entry of the directory at [directoryOffset], or the entry
/// whose numeric id is [wantId] when given.
_ResourceEntry? _findEntry(
  ByteData data,
  int directoryOffset,
  int resourceBase,
  int fileLength, {
  int? wantId,
}) {
  if (directoryOffset + 16 > fileLength) return null;
  final namedCount = data.getUint16(directoryOffset + 12, Endian.little);
  final idCount = data.getUint16(directoryOffset + 14, Endian.little);

  for (var i = 0; i < namedCount + idCount; i++) {
    final offset = directoryOffset + 16 + i * 8;
    if (offset + 8 > fileLength) return null;
    final nameField = data.getUint32(offset, Endian.little);
    final dataField = data.getUint32(offset + 4, Endian.little);
    final isString = nameField & _subdirectoryFlag != 0;
    final id = isString ? -1 : nameField;

    if (wantId != null && (isString || id != wantId)) continue;

    final name = isString
        ? _readResourceName(
            data, resourceBase + (nameField & ~_subdirectoryFlag), fileLength)
        : '#$id';
    if (name == null) continue;

    return _ResourceEntry(
      name: name,
      id: id,
      offset: dataField & ~_subdirectoryFlag,
      isSubdirectory: dataField & _subdirectoryFlag != 0,
    );
  }
  return null;
}

/// A directory name string: a 16-bit character count then unterminated UTF-16.
String? _readResourceName(ByteData data, int offset, int fileLength) {
  if (offset + 2 > fileLength) return null;
  final length = data.getUint16(offset, Endian.little);
  if (offset + 2 + length * 2 > fileLength) return null;
  final units = <int>[];
  for (var i = 0; i < length; i++) {
    units.add(data.getUint16(offset + 2 + i * 2, Endian.little));
  }
  return String.fromCharCodes(units);
}

// --- VS_VERSIONINFO --------------------------------------------------------

/// Walks the version block: root (`VS_FIXEDFILEINFO`) -> `StringFileInfo` ->
/// one node per language/code page -> one node per key.
///
/// Every node is `{wLength, wValueLength, wType, szKey, padding to 4, Value,
/// padding to 4, Children}`. Node lengths are clamped to the enclosing block, so
/// a corrupt `wLength` truncates parsing instead of reading past the resource.
PeVersionResource _parseVersionBlock(
  ByteData data,
  int start,
  int size, {
  required String resourceName,
  required int languageId,
}) {
  final end = start + size;
  final valueLength = data.getUint16(start + 2, Endian.little);
  final key = _readTerminated(data, start + 6, end);
  var cursor = _align4(start + 6 + (key.length + 1) * 2);

  var fileVersion = '';
  var productVersion = '';
  if (valueLength >= 24 &&
      cursor + 24 <= end &&
      data.getUint32(cursor, Endian.little) == _fixedFileInfoSignature) {
    fileVersion = _formatVersion(
      data.getUint32(cursor + 8, Endian.little),
      data.getUint32(cursor + 12, Endian.little),
    );
    productVersion = _formatVersion(
      data.getUint32(cursor + 16, Endian.little),
      data.getUint32(cursor + 20, Endian.little),
    );
  }
  cursor = _align4(cursor + valueLength);

  final tables = <PeStringTable>[];
  while (cursor + 6 <= end) {
    final length = data.getUint16(cursor, Endian.little);
    if (length < 6) break;
    final childEnd = cursor + length < end ? cursor + length : end;
    final childKey = _readTerminated(data, cursor + 6, childEnd);
    if (childKey == 'StringFileInfo') {
      tables.addAll(_parseStringTables(
        data,
        _align4(cursor + 6 + (childKey.length + 1) * 2),
        childEnd,
      ));
    }
    cursor = _align4(cursor + length);
  }

  return PeVersionResource(
    resourceName: resourceName,
    languageId: languageId,
    fixedFileVersion: fileVersion,
    fixedProductVersion: productVersion,
    stringTables: tables,
  );
}

List<PeStringTable> _parseStringTables(ByteData data, int start, int end) {
  final tables = <PeStringTable>[];
  var cursor = start;
  while (cursor + 6 <= end) {
    final length = data.getUint16(cursor, Endian.little);
    if (length < 6) break;
    final tableEnd = cursor + length < end ? cursor + length : end;
    final languageCodePage = _readTerminated(data, cursor + 6, tableEnd);
    tables.add(PeStringTable(
      languageCodePage: languageCodePage,
      values: _parseStringValues(
        data,
        _align4(cursor + 6 + (languageCodePage.length + 1) * 2),
        tableEnd,
      ),
    ));
    cursor = _align4(cursor + length);
  }
  return tables;
}

Map<String, String> _parseStringValues(ByteData data, int start, int end) {
  final values = <String, String>{};
  var cursor = start;
  while (cursor + 6 <= end) {
    final length = data.getUint16(cursor, Endian.little);
    if (length < 6) break;
    final entryEnd = cursor + length < end ? cursor + length : end;
    // wValueLength counts 16-bit words for text values, including the
    // terminator.
    final words = data.getUint16(cursor + 2, Endian.little);
    final name = _readTerminated(data, cursor + 6, entryEnd);
    final valueOffset = _align4(cursor + 6 + (name.length + 1) * 2);
    final valueEnd = valueOffset + words * 2;
    values[name] = words == 0
        ? ''
        : _readTerminated(
            data, valueOffset, valueEnd < entryEnd ? valueEnd : entryEnd);
    cursor = _align4(cursor + length);
  }
  return values;
}

/// Reads a null-terminated UTF-16 string, stopping at [limit].
String _readTerminated(ByteData data, int offset, int limit) {
  final units = <int>[];
  var cursor = offset;
  while (cursor + 2 <= limit) {
    final unit = data.getUint16(cursor, Endian.little);
    if (unit == 0) break;
    units.add(unit);
    cursor += 2;
  }
  return String.fromCharCodes(units);
}

/// The full four-part version; [PeVersionResource.toBinaryFileMetadata] is what
/// truncates it for the cross-platform contract.
String _formatVersion(int versionMS, int versionLS) {
  final major = (versionMS >> 16) & 0xFFFF;
  final minor = versionMS & 0xFFFF;
  final build = (versionLS >> 16) & 0xFFFF;
  final revision = versionLS & 0xFFFF;
  return '$major.$minor.$build.$revision';
}

int _align4(int value) => (value + 3) & ~3;

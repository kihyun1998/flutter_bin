import 'dart:io';
import 'dart:typed_data';

import '../../models/pe_version_resource.dart';
import 'version_info.dart';

/// Reads the version resource out of a PE image, in pure Dart.
///
/// Unlike the `version.dll` reader this needs no FFI and no Windows host — a PE
/// file can be inspected from any platform — and it finds the resource by type
/// alone, so images whose `RT_VERSION` entry is stored under a name string
/// (`VS_VERSION_INFO`, emitted by some `windres` builds) are readable. The Win32
/// version APIs look up the numeric id `1` and report those files as carrying no
/// version info at all.
///
/// Only the headers and the resource section are read, so pointing this at a
/// large binary does not pull the whole file into memory. The consequence is a
/// narrower reach than [parsePeVersionResource]: an image that points its version
/// payload at a section other than the one holding the resource directory reads
/// as null here, while the in-memory parser can still follow it. No PE toolchain
/// is known to emit that layout — the loader maps the resource directory and its
/// data as one region — so this trades an unused capability for not reading the
/// file.
///
/// Returns null when [filePath] is absent, is not a PE image, or has no version
/// resource. Never throws for malformed input.
Future<PeVersionResource?> readPeVersionResource(String filePath) async {
  RandomAccessFile? handle;
  try {
    final file = File(filePath);
    if (!await file.exists()) return null;
    handle = await file.open();
    return await _readFromHandle(handle);
  } on FileSystemException {
    return null;
  } on RangeError {
    return null;
  } finally {
    await handle?.close();
  }
}

/// Parses an in-memory PE image. See [readPeVersionResource]; prefer that when
/// the image is a file, since it reads only the parts it needs.
///
/// Having the whole image in hand, this resolves the version payload through the
/// full section table, wherever it points.
PeVersionResource? parsePeVersionResource(Uint8List bytes) {
  try {
    final data = ByteData.sublistView(bytes);
    final headers = _parseHeaders(data, bytes.length);
    if (headers == null) return null;
    final resourceBase = _rvaToOffset(headers.sections, headers.resourceRva);
    if (resourceBase == null) return null;
    return _readVersionLeaf(data, bytes.length, headers.sections, resourceBase);
  } on RangeError {
    // Defence in depth: every read below is bounds-checked, so reaching here
    // means a case was missed — still no throw for the caller.
    return null;
  }
}

// --- windowed file reads ---------------------------------------------------

/// The initial header read. Big enough to cover the DOS stub, the PE headers and
/// the section table of any ordinary image in one go; anything unusual costs one
/// more read.
const int _headerProbeLength = 0x400;

/// Reads the two regions the parser needs — the headers, then the resource
/// section — instead of the whole file.
Future<PeVersionResource?> _readFromHandle(RandomAccessFile handle) async {
  final fileLength = await handle.length();
  if (fileLength < 0x40) return null;

  var headerBytes = await _readAt(handle, 0, _headerProbeLength, fileLength);
  var headerData = ByteData.sublistView(headerBytes);
  if (headerBytes.length < 0x40) return null;
  if (headerData.getUint16(0, Endian.little) != _dosSignature) return null;

  // The section table's extent is only known after reading the COFF header, so
  // re-read from the start when the probe fell short of it.
  final peOffset = headerData.getUint32(0x3C, Endian.little);
  if (!_within(peOffset, 26, fileLength)) return null;
  if (!_within(peOffset, 26, headerBytes.length)) {
    headerBytes = await _readAt(handle, 0, peOffset + 26, fileLength);
    headerData = ByteData.sublistView(headerBytes);
    if (!_within(peOffset, 26, headerBytes.length)) return null;
  }
  final sectionCount = headerData.getUint16(peOffset + 6, Endian.little);
  final optionalSize = headerData.getUint16(peOffset + 20, Endian.little);
  final headerEnd = peOffset + 24 + optionalSize + sectionCount * 40;
  if (headerEnd > fileLength) return null;
  if (headerEnd > headerBytes.length) {
    headerBytes = await _readAt(handle, 0, headerEnd, fileLength);
    headerData = ByteData.sublistView(headerBytes);
    if (headerEnd > headerBytes.length) return null;
  }

  final headers = _parseHeaders(headerData, headerBytes.length);
  if (headers == null) return null;

  final section = _sectionFor(headers.sections, headers.resourceRva);
  if (section == null) return null;
  final resourceBase =
      section.rawOffset + (headers.resourceRva - section.virtualAddress);
  // The declared directory size can undershoot the section, so take the larger
  // of the two — still just the resource section, not the file.
  final windowLength = _min(
    fileLength - resourceBase,
    _max(headers.resourceSize, section.rawSize),
  );
  if (!_within(resourceBase, 16, fileLength) || windowLength < 16) return null;

  final window = await _readAt(handle, resourceBase, windowLength, fileLength);
  if (window.length < 16) return null;

  // Rebase the sections onto the window so the resource walk keeps working in
  // one coordinate space; sections outside the window fall away.
  final windowSections = [
    for (final candidate in headers.sections)
      if (candidate.rawOffset >= resourceBase) candidate.rebased(resourceBase),
  ];

  // The window starts at the resource directory, so its base is offset 0.
  return _readVersionLeaf(
    ByteData.sublistView(window),
    window.length,
    windowSections,
    0,
  );
}

Future<Uint8List> _readAt(
    RandomAccessFile handle, int start, int count, int fileLength) async {
  final available = fileLength - start;
  final length = count < available ? count : available;
  if (length <= 0) return Uint8List(0);
  await handle.setPosition(start);
  return handle.read(length);
}

// --- PE headers ------------------------------------------------------------

const int _dosSignature = 0x5A4D; // 'MZ'
const int _peSignature = 0x00004550; // 'PE\0\0'
const int _pe32Magic = 0x010B;
const int _pe32PlusMagic = 0x020B;
const int _resourceTableDirectoryIndex = 2;
const int _rtVersion = 16;
const int _subdirectoryFlag = 0x80000000;
const int _fixedFileInfoSignature = 0xFEEF04BD;

class _PeSection {
  const _PeSection({
    required this.virtualAddress,
    required this.virtualSize,
    required this.rawOffset,
    required this.rawSize,
  });

  final int virtualAddress;
  final int virtualSize;
  final int rawOffset;
  final int rawSize;

  _PeSection rebased(int origin) => _PeSection(
        virtualAddress: virtualAddress,
        virtualSize: virtualSize,
        rawOffset: rawOffset - origin,
        rawSize: rawSize,
      );
}

class _PeHeaders {
  const _PeHeaders({
    required this.sections,
    required this.resourceRva,
    required this.resourceSize,
  });

  final List<_PeSection> sections;
  final int resourceRva;
  final int resourceSize;
}

/// Reads the DOS stub, COFF header, optional header data directory and section
/// table. Returns null when the bytes are not a PE image or declare no resource
/// table.
_PeHeaders? _parseHeaders(ByteData data, int length) {
  if (length < 0x40) return null;
  if (data.getUint16(0, Endian.little) != _dosSignature) return null;

  final peOffset = data.getUint32(0x3C, Endian.little);
  if (!_within(peOffset, 24, length)) return null;
  if (data.getUint32(peOffset, Endian.little) != _peSignature) return null;

  final sectionCount = data.getUint16(peOffset + 6, Endian.little);
  final optionalSize = data.getUint16(peOffset + 20, Endian.little);
  final optional = peOffset + 24;
  if (!_within(optional, optionalSize, length)) return null;

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

  final entry = optional + directoryOffset + 8 * _resourceTableDirectoryIndex;
  if (!_within(entry, 8, length)) return null;
  final directoryCount =
      data.getUint32(optional + directoryCountOffset, Endian.little);
  if (directoryCount <= _resourceTableDirectoryIndex) return null;

  final resourceRva = data.getUint32(entry, Endian.little);
  if (resourceRva == 0) return null;

  return _PeHeaders(
    sections:
        _readSections(data, optional + optionalSize, sectionCount, length),
    resourceRva: resourceRva,
    resourceSize: data.getUint32(entry + 4, Endian.little),
  );
}

List<_PeSection> _readSections(
    ByteData data, int tableOffset, int count, int length) {
  final sections = <_PeSection>[];
  for (var i = 0; i < count; i++) {
    final offset = tableOffset + i * 40;
    if (!_within(offset, 40, length)) break;
    sections.add(_PeSection(
      virtualAddress: data.getUint32(offset + 12, Endian.little),
      virtualSize: data.getUint32(offset + 8, Endian.little),
      rawOffset: data.getUint32(offset + 20, Endian.little),
      rawSize: data.getUint32(offset + 16, Endian.little),
    ));
  }
  return sections;
}

_PeSection? _sectionFor(List<_PeSection> sections, int rva) {
  for (final section in sections) {
    final size = section.virtualSize == 0 ? 1 : section.virtualSize;
    if (rva >= section.virtualAddress && rva < section.virtualAddress + size) {
      return section;
    }
  }
  return null;
}

int? _rvaToOffset(List<_PeSection> sections, int rva) {
  final section = _sectionFor(sections, rva);
  if (section == null) return null;
  return section.rawOffset + (rva - section.virtualAddress);
}

// --- resource directory ----------------------------------------------------

/// Walks type -> name -> language and parses the leaf the `RT_VERSION` type
/// points at. The name level accepts any entry, id or string — that is what
/// makes string-named resources readable.
PeVersionResource? _readVersionLeaf(
  ByteData data,
  int length,
  List<_PeSection> sections,
  int resourceBase,
) {
  final typeEntry =
      _findEntry(data, resourceBase, resourceBase, length, wantId: _rtVersion);
  if (typeEntry == null || !typeEntry.isSubdirectory) return null;

  final nameEntry =
      _findEntry(data, resourceBase + typeEntry.offset, resourceBase, length);
  if (nameEntry == null || !nameEntry.isSubdirectory) return null;

  final languageEntry =
      _findEntry(data, resourceBase + nameEntry.offset, resourceBase, length);
  if (languageEntry == null || languageEntry.isSubdirectory) return null;

  final dataEntry = resourceBase + languageEntry.offset;
  if (!_within(dataEntry, 8, length)) return null;
  final payloadRva = data.getUint32(dataEntry, Endian.little);
  final payloadSize = data.getUint32(dataEntry + 4, Endian.little);
  final payloadOffset = _rvaToOffset(sections, payloadRva);
  if (payloadOffset == null || payloadSize < 6) return null;
  if (!_within(payloadOffset, payloadSize, length)) return null;

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
  int length, {
  int? wantId,
}) {
  if (!_within(directoryOffset, 16, length)) return null;
  final namedCount = data.getUint16(directoryOffset + 12, Endian.little);
  final idCount = data.getUint16(directoryOffset + 14, Endian.little);

  for (var i = 0; i < namedCount + idCount; i++) {
    final offset = directoryOffset + 16 + i * 8;
    if (!_within(offset, 8, length)) return null;
    final nameField = data.getUint32(offset, Endian.little);
    final dataField = data.getUint32(offset + 4, Endian.little);
    final isString = nameField & _subdirectoryFlag != 0;
    final id = isString ? -1 : nameField;

    if (wantId != null && (isString || id != wantId)) continue;

    final name = isString
        ? _readResourceName(
            data, resourceBase + (nameField & ~_subdirectoryFlag), length)
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
String? _readResourceName(ByteData data, int offset, int length) {
  if (!_within(offset, 2, length)) return null;
  final characters = data.getUint16(offset, Endian.little);
  if (!_within(offset, 2 + characters * 2, length)) return null;
  final units = <int>[];
  for (var i = 0; i < characters; i++) {
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
    // The four-part version as the resource states it;
    // PeVersionResource.toBinaryFileMetadata applies the semver truncation.
    fileVersion = formatFullVersion(
      data.getUint32(cursor + 8, Endian.little),
      data.getUint32(cursor + 12, Endian.little),
    );
    productVersion = formatFullVersion(
      data.getUint32(cursor + 16, Endian.little),
      data.getUint32(cursor + 20, Endian.little),
    );
  }
  cursor = _align4(cursor + valueLength);

  final tables = <PeStringTable>[];
  while (cursor + 6 <= end) {
    final length = data.getUint16(cursor, Endian.little);
    if (length < 6) break;
    final childEnd = _min(cursor + length, end);
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
    final tableEnd = _min(cursor + length, end);
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
    final entryEnd = _min(cursor + length, end);
    // wValueLength counts 16-bit words for text values, including the
    // terminator.
    final words = data.getUint16(cursor + 2, Endian.little);
    final name = _readTerminated(data, cursor + 6, entryEnd);
    final valueOffset = _align4(cursor + 6 + (name.length + 1) * 2);
    values[name] = words == 0
        ? ''
        : _readTerminated(
            data, valueOffset, _min(valueOffset + words * 2, entryEnd));
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

// --- helpers ---------------------------------------------------------------

/// True when `[offset, offset + count)` lies inside `[0, length)`. Guards both
/// ends: rebasing sections onto a read window can make an offset negative.
bool _within(int offset, int count, int length) =>
    offset >= 0 && count >= 0 && offset + count <= length;

int _align4(int value) => (value + 3) & ~3;

int _min(int a, int b) => a < b ? a : b;

int _max(int a, int b) => a > b ? a : b;

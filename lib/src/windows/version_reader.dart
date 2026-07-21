import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'version_info.dart';

// --- Win32 function signatures ---

typedef _GetFileVersionInfoSizeWNative = Uint32 Function(
    Pointer<Utf16> filename, Pointer<Uint32> handle);
typedef _GetFileVersionInfoSizeWDart = int Function(
    Pointer<Utf16> filename, Pointer<Uint32> handle);

typedef _GetFileVersionInfoWNative = Int32 Function(
    Pointer<Utf16> filename, Uint32 handle, Uint32 len, Pointer<Void> data);
typedef _GetFileVersionInfoWDart = int Function(
    Pointer<Utf16> filename, int handle, int len, Pointer<Void> data);

typedef _VerQueryValueWNative = Int32 Function(
    Pointer<Void> block,
    Pointer<Utf16> subBlock,
    Pointer<Pointer<Void>> buffer,
    Pointer<Uint32> len);
typedef _VerQueryValueWDart = int Function(
    Pointer<Void> block,
    Pointer<Utf16> subBlock,
    Pointer<Pointer<Void>> buffer,
    Pointer<Uint32> len);

typedef _GetFileAttributesWNative = Uint32 Function(Pointer<Utf16> filename);
typedef _GetFileAttributesWDart = int Function(Pointer<Utf16> filename);

// Returned by GetFileAttributesW when the path is missing/inaccessible.
const int _invalidFileAttributes = 0xFFFFFFFF;

// The named version-resource strings, mapped from the output key used by
// [BinaryFileMetadata] to the resource key queried on Windows. Order and set
// match the C++ plugin's `GetBinaryFileMetadata`.
const Map<String, String> _metadataStringFields = {
  'productName': 'ProductName',
  'fileDescription': 'FileDescription',
  'legalCopyright': 'LegalCopyright',
  'originalFilename': 'OriginalFilename',
  'companyName': 'CompanyName',
};

/// Reads Windows PE version-info resources through the Win32 version APIs via
/// `dart:ffi`. Every call here is synchronous; the platform wrapper adapts the
/// results to the async public API.
///
/// This is the Dart port of `windows/flutter_bin_plugin.cpp` — the
/// default-language (`040904B0`) lookup with a `\VarFileInfo\Translation`
/// fallback and the semver truncation are preserved.
class WindowsVersionReader {
  WindowsVersionReader()
      : _version = DynamicLibrary.open('version.dll'),
        _kernel32 = DynamicLibrary.open('kernel32.dll') {
    _getFileVersionInfoSize = _version.lookupFunction<
        _GetFileVersionInfoSizeWNative,
        _GetFileVersionInfoSizeWDart>('GetFileVersionInfoSizeW');
    _getFileVersionInfo = _version.lookupFunction<_GetFileVersionInfoWNative,
        _GetFileVersionInfoWDart>('GetFileVersionInfoW');
    _verQueryValue =
        _version.lookupFunction<_VerQueryValueWNative, _VerQueryValueWDart>(
            'VerQueryValueW');
    _getFileAttributes = _kernel32.lookupFunction<_GetFileAttributesWNative,
        _GetFileAttributesWDart>('GetFileAttributesW');
  }

  final DynamicLibrary _version;
  final DynamicLibrary _kernel32;
  late final _GetFileVersionInfoSizeWDart _getFileVersionInfoSize;
  late final _GetFileVersionInfoWDart _getFileVersionInfo;
  late final _VerQueryValueWDart _verQueryValue;
  late final _GetFileAttributesWDart _getFileAttributes;

  /// Returns the 3-part semantic version, or null when the file is missing or
  /// carries no version resource.
  String? readVersion(String filePath) {
    return using((Arena arena) {
      final block = _loadVersionInfo(filePath, arena);
      if (block == nullptr) return null;
      return _queryFixedFileInfo(block, arena);
    });
  }

  /// Returns the metadata map. Empty when the file is missing or carries no
  /// version resource; individual absent string fields default to `''`.
  Map<String, String> readMetadata(String filePath) {
    return using((Arena arena) {
      final metadata = <String, String>{};
      final block = _loadVersionInfo(filePath, arena);
      if (block == nullptr) return metadata;

      final version = _queryFixedFileInfo(block, arena);
      if (version != null) metadata['version'] = version;

      _metadataStringFields.forEach((outKey, resourceKey) {
        metadata[outKey] = _queryString(block, resourceKey, arena);
      });
      return metadata;
    });
  }

  // Loads the raw version-info block into arena-owned memory. Returns nullptr
  // when the file is missing/inaccessible or has no version resource. Mirrors
  // the C++ `LoadVersionInfo` preamble.
  Pointer<Void> _loadVersionInfo(String filePath, Arena arena) {
    final pathPtr = filePath.toNativeUtf16(allocator: arena);

    if (_getFileAttributes(pathPtr) == _invalidFileAttributes) {
      return nullptr;
    }

    final handle = arena<Uint32>();
    final size = _getFileVersionInfoSize(pathPtr, handle);
    if (size == 0) return nullptr;

    final buffer = arena<Uint8>(size);
    if (_getFileVersionInfo(pathPtr, 0, size, buffer.cast<Void>()) == 0) {
      return nullptr;
    }
    return buffer.cast<Void>();
  }

  // Queries the root `\` block for VS_FIXEDFILEINFO and formats it.
  String? _queryFixedFileInfo(Pointer<Void> block, Arena arena) {
    final subBlock = '\\'.toNativeUtf16(allocator: arena);
    final bufferOut = arena<Pointer<Void>>();
    final lenOut = arena<Uint32>();
    if (_verQueryValue(block, subBlock, bufferOut, lenOut) == 0 ||
        bufferOut.value == nullptr ||
        lenOut.value == 0) {
      return null;
    }
    final info = bufferOut.value.cast<_VsFixedFileInfo>().ref;
    return formatFixedVersion(info.dwFileVersionMS, info.dwFileVersionLS);
  }

  // Reads a named string, trying the default `040904B0` block first and then
  // every translation advertised in `\VarFileInfo\Translation`. Returns `''`
  // when the string is absent under any translation.
  String _queryString(Pointer<Void> block, String key, Arena arena) {
    final direct =
        _queryStringSubBlock(block, stringFileInfoSubBlock(key: key), arena);
    if (direct != null) return direct;

    final bufferOut = arena<Pointer<Void>>();
    final lenOut = arena<Uint32>();
    final translation =
        '\\VarFileInfo\\Translation'.toNativeUtf16(allocator: arena);
    if (_verQueryValue(block, translation, bufferOut, lenOut) == 0 ||
        bufferOut.value == nullptr ||
        lenOut.value == 0) {
      return '';
    }

    // Each entry is two 16-bit words: language id, then code page.
    final entries = bufferOut.value.cast<Uint16>();
    final count = lenOut.value ~/ 4;
    for (var i = 0; i < count; i++) {
      final language = entries[i * 2];
      final codePage = entries[i * 2 + 1];
      final value = _queryStringSubBlock(
        block,
        stringFileInfoSubBlock(
            key: key, language: language, codePage: codePage),
        arena,
      );
      if (value != null) return value;
    }
    return '';
  }

  // Runs a single VerQueryValue for a string sub-block. Returns null when the
  // sub-block is absent so the caller can try the next translation.
  String? _queryStringSubBlock(
      Pointer<Void> block, String subBlock, Arena arena) {
    final subBlockPtr = subBlock.toNativeUtf16(allocator: arena);
    final bufferOut = arena<Pointer<Void>>();
    final lenOut = arena<Uint32>();
    if (_verQueryValue(block, subBlockPtr, bufferOut, lenOut) == 0 ||
        bufferOut.value == nullptr ||
        lenOut.value == 0) {
      return null;
    }
    return bufferOut.value.cast<Utf16>().toDartString();
  }
}

// VS_FIXEDFILEINFO (winver.h). Only the two file-version DWORDs are read, but
// the full layout is declared so field offsets are correct.
final class _VsFixedFileInfo extends Struct {
  @Uint32()
  external int dwSignature;
  @Uint32()
  external int dwStrucVersion;
  @Uint32()
  external int dwFileVersionMS;
  @Uint32()
  external int dwFileVersionLS;
  @Uint32()
  external int dwProductVersionMS;
  @Uint32()
  external int dwProductVersionLS;
  @Uint32()
  external int dwFileFlagsMask;
  @Uint32()
  external int dwFileFlags;
  @Uint32()
  external int dwFileOS;
  @Uint32()
  external int dwFileType;
  @Uint32()
  external int dwFileSubtype;
  @Uint32()
  external int dwFileDateMS;
  @Uint32()
  external int dwFileDateLS;
}

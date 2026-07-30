import 'binary_file_metadata.dart';

/// One `StringFileInfo` string table from a PE version resource.
///
/// A version resource can carry several tables — one per language/code page the
/// binary was built with — and the same key can hold a different value in each.
/// Tables are kept separate rather than merged so choosing between them stays
/// the caller's decision.
class PeStringTable {
  const PeStringTable({
    required this.languageCodePage,
    required this.values,
  });

  /// The 8-hex-digit table name, e.g. `040904B0` (US English / Unicode) or
  /// `000004b0` (language-neutral / Unicode). Reported exactly as it appears in
  /// the image, including its original letter case.
  final String languageCodePage;

  /// Every key present in the table, with the resource's own key names
  /// (`CompanyName`, `ProductName`, `Comments`, `InternalName`, ...). Values are
  /// verbatim; no key is dropped or renamed.
  final Map<String, String> values;
}

/// The version resource as embedded in a PE image — the *image view*.
///
/// This is not the same question `FlutterBin.getBinaryFileMetadata` answers. That
/// one asks the OS, which follows MUI satellite resources and is locale
/// dependent; this one reports what the image itself carries. The two agree for
/// most binaries and differ for MUI-based ones (`mstsc.exe` reports
/// `mstsc.exe.mui` through the OS and `mstsc.exe` here).
class PeVersionResource {
  const PeVersionResource({
    required this.resourceName,
    required this.languageId,
    required this.fixedFileVersion,
    required this.fixedProductVersion,
    required this.stringTables,
  });

  /// How the `RT_VERSION` entry is named in the resource directory: `#1` for the
  /// conventional numeric id, or the name string for images that use one (some
  /// `windres` builds emit `VS_VERSION_INFO`, which the Win32 version APIs
  /// cannot find because they look up the numeric id only).
  final String resourceName;

  /// The language id of the resource directory leaf, e.g. 1033.
  final int languageId;

  /// The 4-part `dwFileVersion` from `VS_FIXEDFILEINFO`, e.g. `3.66.5.0`.
  /// Empty when the resource carries no fixed file info.
  final String fixedFileVersion;

  /// The 4-part `dwProductVersion` from `VS_FIXEDFILEINFO`. Empty when the
  /// resource carries no fixed file info.
  final String fixedProductVersion;

  /// Every `StringFileInfo` table found, in the order the image lists them.
  final List<PeStringTable> stringTables;

  /// Reads [key] from the first table that has it, or null when no table does.
  ///
  /// Use [stringTables] directly when the image is multi-language and the choice
  /// of table matters.
  String? value(String key) {
    for (final table in stringTables) {
      final value = table.values[key];
      if (value != null) return value;
    }
    return null;
  }

  /// Maps the image view onto [BinaryFileMetadata] so callers can reuse code
  /// written against the OS-view API.
  ///
  /// `version` is truncated to `major.minor.build` to match the cross-platform
  /// version contract (ADR-0003); absent strings become `''`.
  BinaryFileMetadata toBinaryFileMetadata() {
    return BinaryFileMetadata(
      version: _semanticVersion(),
      productName: value('ProductName') ?? '',
      fileDescription: value('FileDescription') ?? '',
      legalCopyright: value('LegalCopyright') ?? '',
      originalFilename: value('OriginalFilename') ?? '',
      companyName: value('CompanyName') ?? '',
    );
  }

  String _semanticVersion() {
    if (fixedFileVersion.isEmpty) return '';
    final parts = fixedFileVersion.split('.');
    if (parts.length <= 3) return fixedFileVersion;
    return parts.take(3).join('.');
  }
}

// Pure, platform-independent helpers for interpreting the Windows
// version-info resource. Kept free of `dart:ffi` / `dart:io` so they can be
// unit-tested on any host (including the Linux CI job).

/// Formats a fixed file-info version as a semantic `major.minor.build`.
///
/// [fileVersionMS] and [fileVersionLS] are the `dwFileVersionMS` /
/// `dwFileVersionLS` fields of `VS_FIXEDFILEINFO`. The Windows file version is
/// `major.minor.build.revision`; the trailing revision is dropped so the value
/// matches semver across platforms (see #5 / ADR-0003).
String formatFixedVersion(int fileVersionMS, int fileVersionLS) {
  final major = (fileVersionMS >> 16) & 0xFFFF;
  final minor = fileVersionMS & 0xFFFF;
  final build = (fileVersionLS >> 16) & 0xFFFF;
  return '$major.$minor.$build';
}

/// Builds a `VerQueryValue` sub-block path for a named string such as
/// `ProductName`.
///
/// With no [language]/[codePage] this targets the default US-English Unicode
/// block using the hardcoded uppercase `040904B0`, matching the C++ plugin's
/// first-choice query. When a [language]/[codePage] pair is supplied (from the
/// `\VarFileInfo\Translation` table) each is formatted as 4-digit lowercase hex,
/// mirroring the C++ `%04x%04x` fallback path.
String stringFileInfoSubBlock({
  required String key,
  int? language,
  int? codePage,
}) {
  if (language == null || codePage == null) {
    return '\\StringFileInfo\\040904B0\\$key';
  }
  final lang = language.toRadixString(16).padLeft(4, '0');
  final cp = codePage.toRadixString(16).padLeft(4, '0');
  return '\\StringFileInfo\\$lang$cp\\$key';
}

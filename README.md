# flutter_bin — Binary File Metadata

[![pub package](https://img.shields.io/pub/v/flutter_bin.svg)](https://pub.dev/packages/flutter_bin)

A pure-Dart package to retrieve metadata from binary files (executable files) on desktop platforms. Supports Windows and macOS, and works in both Flutter and plain Dart projects. Windows asks the OS for the PE version resource via `dart:ffi`, or parses the resource out of the image itself when you want what the binary carries ([Two Views of a Windows Binary](#two-views-of-a-windows-binary)); macOS parses the app bundle's `Info.plist`. Calls on unsupported platforms throw `UnsupportedError`.

## Features

- Retrieve file version information from binary files
- Extract comprehensive metadata including:
  - Version
  - Product name
  - File description
  - Legal copyright
  - Original filename
  - Company name
- Read the PE version resource straight out of the image — including binaries the
  Win32 version APIs report as having none ([Two Views of a Windows Binary](#two-views-of-a-windows-binary))
- Easy integration with file pickers

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_bin: ^3.1.0
```

## Usage

### Basic Version Retrieval

```dart
import 'package:flutter_bin/flutter_bin.dart';

// Create an instance
final flutterBin = FlutterBin();

// Get the version information
final String? version = await flutterBin.getBinaryFileVersion('C:\\path\\to\\file.exe');
print('File version: $version');

// On macOS
final String? macVersion = await flutterBin.getBinaryFileVersion('/Applications/Example.app');
print('macOS app version: $macVersion');
```

### Full Metadata Retrieval

```dart
import 'package:flutter_bin/flutter_bin.dart';

// Create an instance
final flutterBin = FlutterBin();

// Get comprehensive metadata (Windows)
final metadata = await flutterBin.getBinaryFileMetadata('C:\\path\\to\\file.exe');

// Or for macOS
final macMetadata = await flutterBin.getBinaryFileMetadata('/Applications/Example.app');

// Access specific properties
print('File version: ${metadata.version}');
print('Product name: ${metadata.productName}');
print('File description: ${metadata.fileDescription}');
print('Copyright: ${metadata.legalCopyright}');
print('Original filename: ${metadata.originalFilename}');
print('Company name: ${metadata.companyName}');
```

### With FilePicker

```dart
import 'package:flutter_bin/flutter_bin.dart';
import 'package:file_picker/file_picker.dart';

// Create an instance
final flutterBin = FlutterBin();

// Let the user select a file
FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.any,
  allowMultiple: false,
);

if (result != null && result.files.single.path != null) {
  final filePath = result.files.single.path!;
  
  // Get metadata for the selected file
  final metadata = await flutterBin.getBinaryFileMetadata(filePath);
  print('File version: ${metadata.version}');
}
```

## Metadata Fields

flutter_bin extracts the following metadata from binary files:

| Field | Description | Windows Source | macOS Source |
|-------|-------------|----------------|--------------|
| version | Semantic version (e.g., 1.2.3) | FileVersion (major.minor.build) | CFBundleShortVersionString |
| productName | The product name | ProductName | CFBundleName |
| fileDescription | Description of the file | FileDescription | CFBundleGetInfoString |
| legalCopyright | Copyright information | LegalCopyright | NSHumanReadableCopyright |
| originalFilename | Original name of the file | OriginalFilename | CFBundleExecutable |
| companyName | Company or developer name | CompanyName | Not typically available |

## Two Views of a Windows Binary

`getBinaryFileMetadata` asks the operating system what it reports for a file. That
is what you normally want, but it has two consequences: the values can come from a
MUI satellite resource rather than the binary itself, and a binary whose
`RT_VERSION` resource is stored under a *name string* instead of the numeric id
`1` reads as having no version info at all — the Win32 version APIs look up the
numeric id only. Some `windres` builds emit such resources (FileZilla 3.66.5, for
example), and Explorer shows nothing for them either.

`package:flutter_bin/pe.dart` adds the *image view*: it parses the PE file
directly, finds the version resource by type regardless of how the entry is named,
and returns everything the resource carries.

```dart
import 'package:flutter_bin/pe.dart';

final resource = await readPeVersionResource(path); // null if not a PE / no resource
if (resource != null) {
  print(resource.resourceName);          // '#1', or 'VS_VERSION_INFO'
  print(resource.fixedFileVersion);      // '3.66.5.0' (four parts)
  print(resource.value('CompanyName'));  // 'FileZilla Project'

  for (final table in resource.stringTables) {
    print('${table.languageCodePage}: ${table.values}'); // every key, every table
  }

  final metadata = resource.toBinaryFileMetadata(); // same model as the OS view
}
```

| | `getBinaryFileMetadata` (OS view) | `readPeVersionResource` (image view) |
|---|---|---|
| Question answered | What does the OS report for this file? | What is embedded in this image? |
| Follows MUI satellites | Yes | No |
| Locale dependent | Yes | No |
| String-named `RT_VERSION` | Not readable | Readable |
| Fields | The six in the table above | Resource name, language id, four-part file/product versions, every string table with every key |
| Host platform | Windows only | Any (pure Dart) |
| File I/O | Delegated to `version.dll` | Two windowed reads: headers, then the resource section |

An image can carry several version resources — one per language, and in principle
one per entry name. `readPeVersionResource` returns the one the OS would pick (the
numeric id `1` entry, else the first the directory lists);
`readPeVersionResources` returns them all, in resource-directory order.

```dart
for (final resource in await readPeVersionResources(path)) {
  print('${resource.resourceName} / ${resource.languageId}');
}
```

That selection rule matters because resource directories sort *named* entries
before numeric ones: without it, an image carrying both `#1` and
`VS_VERSION_INFO` would report the named entry here and the `#1` entry through the
OS view. Entry selection is the third way the two views can diverge, after MUI and
locale.

The views agree for most binaries and disagree where MUI is involved:
`C:\Windows\System32\mstsc.exe` reports `originalFilename` as `mstsc.exe.mui`
through the OS view and `mstsc.exe` through the image view. Both are correct for
the question they answer, so the two are not interchangeable — pick per call site
rather than treating one as a fallback for the other.

macOS needs no equivalent: `Info.plist` is read from the bundle directly, so there
is no hidden-resource case to recover.

## Platform Support

| Platform | Status |
|----------|--------|
| Windows  | ✅ Supported (OS view + PE image view) |
| macOS    | ✅ Supported |
| Linux    | ❌ Planned (PE image view already works from any host) |

## File Path Formats

### Windows
Use standard Windows paths with double backslashes or forward slashes:
```
C:\\Program Files\\Application\\app.exe
```
or
```
C:/Program Files/Application/app.exe
```

### macOS
For macOS applications (.app bundles):
```
/Applications/Example.app
```
or specific binaries within the bundle:
```
/Applications/Example.app/Contents/MacOS/Example
```

## Example

The package includes a full example showcasing all features. To run the example:

```
cd example
flutter run
```

Pick a binary, then compare the buttons: **Get Full Metadata** shows the OS view,
and **Read PE Image View** shows every version resource in the image — each key
with its value, the leaf the singular API selects, and the result of
`toBinaryFileMetadata()`. Pointing it at a binary like FileZilla 3.66.5 shows the
OS view reading nothing while the image view reads all nine keys.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

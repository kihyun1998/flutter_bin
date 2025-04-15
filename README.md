# Flutter Binary File Metadata Plugin

[![pub package](https://img.shields.io/pub/v/flutter_bin.svg)](https://pub.dev/packages/flutter_bin)

A Flutter plugin to retrieve metadata from binary files (executable files) on desktop platforms. Currently supports Windows platform.

## Features

- Retrieve file version information from binary files
- Extract comprehensive metadata including:
  - Version
  - Product name
  - File description
  - Legal copyright
  - Original filename
  - Company name
- Easy integration with file pickers

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_bin: ^1.0.0
```

## Usage

### Basic Version Retrieval

```dart
import 'package:flutter_bin/flutter_bin.dart';

// Create an instance of the plugin
final flutterBin = FlutterBin();

// Get the version information
final String? version = await flutterBin.getBinaryFileVersion('C:\\path\\to\\file.exe');
print('File version: $version');
```

### Full Metadata Retrieval

```dart
import 'package:flutter_bin/flutter_bin.dart';

// Create an instance of the plugin
final flutterBin = FlutterBin();

// Get comprehensive metadata
final metadata = await flutterBin.getBinaryFileMetadata('C:\\path\\to\\file.exe');

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

// Create an instance of the plugin
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

The plugin extracts the following metadata from Windows binary files:

| Field | Description | Windows Source |
|-------|-------------|----------------|
| version | File version (e.g., 1.2.3.4) | FileVersion |
| productName | The product name | ProductName |
| fileDescription | Description of the file | FileDescription |
| legalCopyright | Copyright information | LegalCopyright |
| originalFilename | Original name of the file | OriginalFilename |
| companyName | Company or developer name | CompanyName |

## Platform Support

| Platform | Status |
|----------|--------|
| Windows  | ✅ Supported |
| macOS    | ❌ Planned |
| Linux    | ❌ Planned |

## Example

The package includes a full example showcasing all features. To run the example:

```
cd example
flutter run
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
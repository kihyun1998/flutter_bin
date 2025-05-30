# flutter_bin
## Project Structure

```
flutter_bin/
├── example/
    ├── integration_test/
    │   └── plugin_integration_test.dart
    ├── lib/
    │   └── main.dart
    └── test/
    │   └── widget_test.dart
├── lib/
    ├── models/
    │   └── binary_file_metadata.dart
    ├── flutter_bin.dart
    ├── flutter_bin_method_channel.dart
    └── flutter_bin_platform_interface.dart
├── test/
    ├── flutter_bin_method_channel_test.dart
    └── flutter_bin_test.dart
└── windows/
    ├── include/
        └── flutter_bin/
        │   └── flutter_bin_plugin_c_api.h
    ├── test/
        └── flutter_bin_plugin_test.cpp
    ├── CMakeLists.txt
    ├── flutter_bin_plugin.cpp
    ├── flutter_bin_plugin.h
    └── flutter_bin_plugin_c_api.cpp
```

## example/integration_test/plugin_integration_test.dart
```dart
// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_bin/flutter_bin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getPlatformVersion test', (WidgetTester tester) async {
    final FlutterBin plugin = FlutterBin();
  });
}

```
## example/lib/main.dart
```dart
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bin/flutter_bin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _fileVersion = 'No file selected';
  BinaryFileMetadata? _fileMetadata;
  final _flutterBinPlugin = FlutterBin();
  final _filePathController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _filePathController.dispose();
    super.dispose();
  }

  // Method 1: Get version from manually entered file path
  Future<void> _getFileVersionFromPath() async {
    String fileVersion;
    final filePath = _filePathController.text.trim();

    if (filePath.isEmpty) {
      fileVersion = 'Please enter a file path';
      setState(() {
        _fileVersion = fileVersion;
        _fileMetadata = null;
      });
      return;
    }

    try {
      final version = await _flutterBinPlugin.getBinaryFileVersion(filePath);
      fileVersion = version ?? 'No version information available';
    } on PlatformException catch (e) {
      fileVersion = 'Error: ${e.message}';
    }

    if (!mounted) return;

    setState(() {
      _fileVersion = fileVersion;
      _fileMetadata = null; // Clear metadata when only version is retrieved
    });
  }

  // Method 2: Get version using FilePicker
  Future<void> _pickFileAndGetVersion() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        _filePathController.text = filePath; // Update the text field

        final version = await _flutterBinPlugin.getBinaryFileVersion(filePath);
        final fileVersion = version ?? 'No version information available';

        if (!mounted) return;

        setState(() {
          _fileVersion = fileVersion;
          _fileMetadata = null; // Clear metadata when only version is retrieved
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _fileVersion = 'Error: ${e.message}';
        _fileMetadata = null;
      });
    }
  }

  // Method 3: Get full metadata
  Future<void> _getFullMetadata() async {
    final filePath = _filePathController.text.trim();

    if (filePath.isEmpty) {
      setState(() {
        _fileMetadata = null;
        _fileVersion = 'Please enter a file path';
      });
      return;
    }

    try {
      final metadata = await _flutterBinPlugin.getBinaryFileMetadata(filePath);

      if (!mounted) return;

      setState(() {
        _fileMetadata = metadata;
        _fileVersion = metadata.version.isNotEmpty
            ? metadata.version
            : 'No version information available';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _fileMetadata = null;
        _fileVersion = 'Error: ${e.message}';
      });
    }
  }

  // Method 4: Pick file and get full metadata
  Future<void> _pickFileAndGetMetadata() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        _filePathController.text = filePath; // Update the text field

        final metadata =
            await _flutterBinPlugin.getBinaryFileMetadata(filePath);

        if (!mounted) return;

        setState(() {
          _fileMetadata = metadata;
          _fileVersion = metadata.version.isNotEmpty
              ? metadata.version
              : 'No version information available';
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _fileMetadata = null;
        _fileVersion = 'Error: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Binary File Metadata Plugin'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File path input
              const Text('Enter file path or select file:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _filePathController,
                decoration: const InputDecoration(
                  hintText: 'C:\\path\\to\\file.exe',
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _getFileVersionFromPath,
                    child: const Text('Get Version Only'),
                  ),
                  ElevatedButton(
                    onPressed: _getFullMetadata,
                    child: const Text('Get Full Metadata'),
                  ),
                  ElevatedButton(
                    onPressed: _pickFileAndGetVersion,
                    child: const Text('Select & Get Version'),
                  ),
                  ElevatedButton(
                    onPressed: _pickFileAndGetMetadata,
                    child: const Text('Select & Get Metadata'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Basic version result
              const Text('File Version:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_fileVersion),

              // Full metadata display (when available)
              if (_fileMetadata != null) ...[
                const SizedBox(height: 16),
                const Text('Full Metadata:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildMetadataTable(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
      },
      children: [
        _buildTableRow('Version', _fileMetadata!.version),
        _buildTableRow('Product Name', _fileMetadata!.productName),
        _buildTableRow('File Description', _fileMetadata!.fileDescription),
        _buildTableRow('Copyright', _fileMetadata!.legalCopyright),
        _buildTableRow('Original Filename', _fileMetadata!.originalFilename),
        _buildTableRow('Company Name', _fileMetadata!.companyName),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(value.isEmpty ? 'Not available' : value),
        ),
      ],
    );
  }
}

```
## example/test/widget_test.dart
```dart
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bin_example/main.dart';

void main() {
  testWidgets('Verify Platform version', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that platform version is retrieved.
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text &&
                           widget.data!.startsWith('Running on:'),
      ),
      findsOneWidget,
    );
  });
}

```
## lib/flutter_bin.dart
```dart
import 'flutter_bin_platform_interface.dart';
import 'models/binary_file_metadata.dart';

export 'models/binary_file_metadata.dart';

class FlutterBin {
  /// Gets the version of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns the version string of the file (e.g. '1.2.3.4').
  /// Returns null if the file doesn't exist or version information is not available.
  Future<String?> getBinaryFileVersion(String filePath) {
    return FlutterBinPlatform.instance.getBinaryFileVersion(filePath);
  }

  /// Gets comprehensive metadata of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns a [BinaryFileMetadata] object containing available metadata.
  /// Fields may be null if the corresponding information is not available.
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) {
    return FlutterBinPlatform.instance.getBinaryFileMetadata(filePath);
  }
}

```
## lib/flutter_bin_method_channel.dart
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_bin_platform_interface.dart';
import 'models/binary_file_metadata.dart';

/// An implementation of [FlutterBinPlatform] that uses method channels.
class MethodChannelFlutterBin extends FlutterBinPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_bin');

  @override
  Future<String?> getBinaryFileVersion(String filePath) async {
    final version = await methodChannel
        .invokeMethod<String?>('getBinaryFileVersion', {'filePath': filePath});
    return version;
  }

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) async {
    final Map<String, dynamic>? result = await methodChannel
        .invokeMapMethod<String, dynamic>(
            'getBinaryFileMetadata', {'filePath': filePath});

    if (result == null) {
      return BinaryFileMetadata();
    }

    return BinaryFileMetadata.fromJson(result);
  }
}

```
## lib/flutter_bin_platform_interface.dart
```dart
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_bin_method_channel.dart';
import 'models/binary_file_metadata.dart';

abstract class FlutterBinPlatform extends PlatformInterface {
  /// Constructs a FlutterBinPlatform.
  FlutterBinPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBinPlatform _instance = MethodChannelFlutterBin();

  /// The default instance of [FlutterBinPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBin].
  static FlutterBinPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBinPlatform] when
  /// they register themselves.
  static set instance(FlutterBinPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Gets the version of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns the version string of the file or null if not available.
  Future<String?> getBinaryFileVersion(String filePath) {
    throw UnimplementedError(
        'getBinaryFileVersion() has not been implemented.');
  }

  /// Gets comprehensive metadata of a binary file.
  ///
  /// [filePath] is the absolute path to the binary file.
  /// Returns a [BinaryFileMetadata] object containing available metadata.
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) {
    throw UnimplementedError(
        'getBinaryFileMetadata() has not been implemented.');
  }
}

```
## lib/models/binary_file_metadata.dart
```dart
enum BinaryFileMetadataJsonKey {
  version,
  productName,
  fileDescription,
  legalCopyright,
  originalFilename,
  companyName,
  ;

  String get key {
    return toString().split('.').last;
  }
}

/// Represents file metadata information
class BinaryFileMetadata {
  final String version;
  final String productName;
  final String fileDescription;
  final String legalCopyright;
  final String originalFilename;
  final String companyName;

  factory BinaryFileMetadata.fromJson(Map<String, dynamic> json) {
    return BinaryFileMetadata(
      version: json[BinaryFileMetadataJsonKey.version.key] ?? '',
      productName: json[BinaryFileMetadataJsonKey.productName.key] ?? '',
      fileDescription:
          json[BinaryFileMetadataJsonKey.fileDescription.key] ?? '',
      legalCopyright: json[BinaryFileMetadataJsonKey.legalCopyright.key] ?? '',
      originalFilename:
          json[BinaryFileMetadataJsonKey.originalFilename.key] ?? '',
      companyName: json[BinaryFileMetadataJsonKey.companyName.key] ?? '',
    );
  }

  BinaryFileMetadata({
    this.version = '',
    this.productName = '',
    this.fileDescription = '',
    this.legalCopyright = '',
    this.originalFilename = '',
    this.companyName = '',
  });
}

```
## test/flutter_bin_method_channel_test.dart
```dart
import 'package:flutter/services.dart';
import 'package:flutter_bin/flutter_bin_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterBin platform = MethodChannelFlutterBin();
  const MethodChannel channel = MethodChannel('flutter_bin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getBinaryFileVersion') {
          return '1.2.3.4';
        } else if (methodCall.method == 'getBinaryFileMetadata') {
          // Return mock metadata
          return {
            'version': '1.2.3.4',
            'productName': 'Test Product',
            'fileDescription': 'Test File Description',
            'legalCopyright': '© 2025 Test Company',
            'originalFilename': 'test.exe',
            'companyName': 'Test Company',
          };
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getBinaryFileVersion', () async {
    expect(await platform.getBinaryFileVersion('test.exe'), '1.2.3.4');
  });

  test('getBinaryFileMetadata', () async {
    final metadata = await platform.getBinaryFileMetadata('test.exe');

    expect(metadata.version, '1.2.3.4');
    expect(metadata.productName, 'Test Product');
    expect(metadata.fileDescription, 'Test File Description');
    expect(metadata.legalCopyright, '© 2025 Test Company');
    expect(metadata.originalFilename, 'test.exe');
    expect(metadata.companyName, 'Test Company');
  });
}

```
## test/flutter_bin_test.dart
```dart
import 'package:flutter_bin/flutter_bin.dart';
import 'package:flutter_bin/flutter_bin_method_channel.dart';
import 'package:flutter_bin/flutter_bin_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBinPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBinPlatform {
  @override
  Future<String?> getBinaryFileVersion(String filePath) async {
    return '1.2.3.4';
  }

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) async {
    return BinaryFileMetadata(
      version: '1.2.3.4',
      productName: 'Mock Product',
      fileDescription: 'Mock File Description',
      legalCopyright: '© 2025 Mock Company',
      originalFilename: 'mock.exe',
      companyName: 'Mock Company',
    );
  }
}

void main() {
  final FlutterBinPlatform initialPlatform = FlutterBinPlatform.instance;

  test('$MethodChannelFlutterBin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterBin>());
  });

  test('getBinaryFileVersion', () async {
    FlutterBin flutterBinPlugin = FlutterBin();
    MockFlutterBinPlatform fakePlatform = MockFlutterBinPlatform();
    FlutterBinPlatform.instance = fakePlatform;

    expect(await flutterBinPlugin.getBinaryFileVersion('test.exe'), '1.2.3.4');
  });

  test('getBinaryFileMetadata', () async {
    FlutterBin flutterBinPlugin = FlutterBin();
    MockFlutterBinPlatform fakePlatform = MockFlutterBinPlatform();
    FlutterBinPlatform.instance = fakePlatform;

    final metadata = await flutterBinPlugin.getBinaryFileMetadata('test.exe');

    expect(metadata.version, '1.2.3.4');
    expect(metadata.productName, 'Mock Product');
    expect(metadata.fileDescription, 'Mock File Description');
    expect(metadata.legalCopyright, '© 2025 Mock Company');
    expect(metadata.originalFilename, 'mock.exe');
    expect(metadata.companyName, 'Mock Company');
  });
}

```
## windows/CMakeLists.txt
```txt
# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "flutter_bin")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_bin_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "flutter_bin_plugin.cpp"
  "flutter_bin_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/flutter_bin/flutter_bin_plugin_c_api.h"
  "flutter_bin_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
  
# Link required libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin Version Ole32 Shell32)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(flutter_bin_bundled_libraries
  ""
  PARENT_SCOPE
)
```
## windows/flutter_bin_plugin.cpp
```cpp
#include "flutter_bin_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For version info
#include <winver.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <string>

// Need to link with Version.lib
#pragma comment(lib, "Version.lib")

namespace flutter_bin {

// static
void FlutterBinPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_bin",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterBinPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterBinPlugin::FlutterBinPlugin() {}

FlutterBinPlugin::~FlutterBinPlugin() {}

void FlutterBinPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("getBinaryFileVersion") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    
    if (arguments) {
      auto file_path_it = arguments->find(flutter::EncodableValue("filePath"));
      if (file_path_it != arguments->end()) {
        const std::string& file_path = std::get<std::string>(file_path_it->second);
        std::string version = GetBinaryFileVersion(file_path);
        if (!version.empty()) {
          result->Success(flutter::EncodableValue(version));
        } else {
          result->Success(nullptr);
        }
      } else {
        result->Error("INVALID_ARGUMENT", "Argument 'filePath' not found");
      }
    } else {
      result->Error("INVALID_ARGUMENT", "Arguments must be a map");
    }
  } 
  else if (method_call.method_name().compare("getBinaryFileMetadata") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    
    if (arguments) {
      auto file_path_it = arguments->find(flutter::EncodableValue("filePath"));
      if (file_path_it != arguments->end()) {
        const std::string& file_path = std::get<std::string>(file_path_it->second);
        std::map<std::string, std::string> metadata_map = GetBinaryFileMetadata(file_path);
        
        // Convert std::map to flutter::EncodableMap
        flutter::EncodableMap result_map;
        for (const auto& pair : metadata_map) {
          result_map[flutter::EncodableValue(pair.first)] = flutter::EncodableValue(pair.second);
        }
        
        result->Success(flutter::EncodableValue(result_map));
      } else {
        result->Error("INVALID_ARGUMENT", "Argument 'filePath' not found");
      }
    } else {
      result->Error("INVALID_ARGUMENT", "Arguments must be a map");
    }
  }
  else {
    result->NotImplemented();
  }
}

std::string FlutterBinPlugin::GetBinaryFileVersion(const std::string& file_path) {
  // Convert from UTF-8 to wide string
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, NULL, 0);
  std::wstring wide_path(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, &wide_path[0], size_needed);

  // Check if file exists
  DWORD file_attributes = GetFileAttributesW(wide_path.c_str());
  if (file_attributes == INVALID_FILE_ATTRIBUTES) {
    // File doesn't exist or is inaccessible
    return "";
  }

  // Get the size of the version info
  DWORD dummy;
  DWORD version_info_size = GetFileVersionInfoSizeW(wide_path.c_str(), &dummy);
  if (version_info_size == 0) {
    // Could not get version info size
    return "";
  }

  // Allocate memory for the version info
  std::vector<BYTE> version_info(version_info_size);
  if (!GetFileVersionInfoW(wide_path.c_str(), 0, version_info_size, version_info.data())) {
    // Could not get version info
    return "";
  }

  // Get the fixed file info
  VS_FIXEDFILEINFO* fixed_file_info = nullptr;
  UINT len = 0;
  if (!VerQueryValueW(version_info.data(), L"\\", (LPVOID*)&fixed_file_info, &len)) {
    // Could not get fixed file info
    return "";
  }

  // Extract the version
  DWORD major = HIWORD(fixed_file_info->dwFileVersionMS);
  DWORD minor = LOWORD(fixed_file_info->dwFileVersionMS);
  DWORD build = HIWORD(fixed_file_info->dwFileVersionLS);
  DWORD revision = LOWORD(fixed_file_info->dwFileVersionLS);

  // Format the version string
  std::ostringstream version_stream;
  version_stream << major << "." << minor << "." << build << "." << revision;
  return version_stream.str();
}

// Helper function to convert Wide String to UTF-8
std::string WideStringToUtf8(const wchar_t* wide_str, int length = -1) {
  if (!wide_str) return "";
  
  // Calculate the required buffer size
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide_str, length, NULL, 0, NULL, NULL);
  if (size_needed <= 0) return "";

  // Allocate the buffer and convert
  std::string utf8_str(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide_str, length, &utf8_str[0], size_needed, NULL, NULL);
  
  // If we got a null-terminated string with explicit length, remove the null terminator from the result
  if (length == -1 && !utf8_str.empty() && utf8_str.back() == '\0') {
    utf8_str.pop_back();
  }
  
  return utf8_str;
}

// Helper to get a string value from version info
std::string GetVersionInfoString(const std::vector<BYTE>& version_info, const std::wstring& sub_block) {
  UINT size = 0;
  LPVOID buffer = nullptr;
  
  // First try to get string with default language
  std::wstring query = L"\\StringFileInfo\\040904B0\\" + sub_block;
  if (VerQueryValueW(version_info.data(), query.c_str(), &buffer, &size) && size > 0 && buffer != nullptr) {
    return WideStringToUtf8(static_cast<const wchar_t*>(buffer));
  }
  
  // If that fails, try to find any available language
  struct LANGANDCODEPAGE {
    WORD language;
    WORD code_page;
  } *translate;
  
  UINT translate_size = 0;
  if (!VerQueryValueW(version_info.data(), L"\\VarFileInfo\\Translation", 
                     reinterpret_cast<LPVOID*>(&translate), &translate_size)) {
    return "";
  }
  
  size_t count = translate_size / sizeof(LANGANDCODEPAGE);
  for (size_t i = 0; i < count; ++i) {
    // Format the language and codepage as a string for the query
    wchar_t sub_block_lang[50];
    swprintf_s(sub_block_lang, L"\\StringFileInfo\\%04x%04x\\%s", 
              translate[i].language, translate[i].code_page, sub_block.c_str());
    
    if (VerQueryValueW(version_info.data(), sub_block_lang, &buffer, &size) && size > 0 && buffer != nullptr) {
      return WideStringToUtf8(static_cast<const wchar_t*>(buffer));
    }
  }
  
  return "";
}

std::map<std::string, std::string> FlutterBinPlugin::GetBinaryFileMetadata(const std::string& file_path) {
  std::map<std::string, std::string> metadata;
  
  // Convert from UTF-8 to wide string
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, NULL, 0);
  std::wstring wide_path(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, &wide_path[0], size_needed);

  // Check if file exists
  DWORD file_attributes = GetFileAttributesW(wide_path.c_str());
  if (file_attributes == INVALID_FILE_ATTRIBUTES) {
    // File doesn't exist or is inaccessible
    return metadata;
  }

  // Get the size of the version info
  DWORD dummy;
  DWORD version_info_size = GetFileVersionInfoSizeW(wide_path.c_str(), &dummy);
  if (version_info_size == 0) {
    // Could not get version info size
    return metadata;
  }

  // Allocate memory for the version info
  std::vector<BYTE> version_info(version_info_size);
  if (!GetFileVersionInfoW(wide_path.c_str(), 0, version_info_size, version_info.data())) {
    // Could not get version info
    return metadata;
  }

  // Get the fixed file info for version
  VS_FIXEDFILEINFO* fixed_file_info = nullptr;
  UINT len = 0;
  if (VerQueryValueW(version_info.data(), L"\\", (LPVOID*)&fixed_file_info, &len)) {
    // Extract the version
    DWORD major = HIWORD(fixed_file_info->dwFileVersionMS);
    DWORD minor = LOWORD(fixed_file_info->dwFileVersionMS);
    DWORD build = HIWORD(fixed_file_info->dwFileVersionLS);
    DWORD revision = LOWORD(fixed_file_info->dwFileVersionLS);

    // Format the version string
    std::ostringstream version_stream;
    version_stream << major << "." << minor << "." << build << "." << revision;
    metadata["version"] = version_stream.str();
  }

  // Get string values from version info
  metadata["productName"] = GetVersionInfoString(version_info, L"ProductName");
  metadata["fileDescription"] = GetVersionInfoString(version_info, L"FileDescription");
  metadata["legalCopyright"] = GetVersionInfoString(version_info, L"LegalCopyright");
  metadata["originalFilename"] = GetVersionInfoString(version_info, L"OriginalFilename");
  metadata["companyName"] = GetVersionInfoString(version_info, L"CompanyName");

  return metadata;
}

}  // namespace flutter_bin
```
## windows/flutter_bin_plugin.h
```h
#ifndef FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace flutter_bin {

class FlutterBinPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterBinPlugin();

  virtual ~FlutterBinPlugin();

  // Disallow copy and assign.
  FlutterBinPlugin(const FlutterBinPlugin&) = delete;
  FlutterBinPlugin& operator=(const FlutterBinPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
      
 private:
  // Methods to handle specific platform calls
  std::string GetBinaryFileVersion(const std::string& file_path);
  
  // Get comprehensive metadata about a binary file
  std::map<std::string, std::string> GetBinaryFileMetadata(const std::string& file_path);
};

}  // namespace flutter_bin

#endif  // FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_H_
```
## windows/flutter_bin_plugin_c_api.cpp
```cpp
#include "include/flutter_bin/flutter_bin_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_bin_plugin.h"

void FlutterBinPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_bin::FlutterBinPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

```
## windows/include/flutter_bin/flutter_bin_plugin_c_api.h
```h
#ifndef FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void FlutterBinPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_C_API_H_

```
## windows/test/flutter_bin_plugin_test.cpp
```cpp
#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "flutter_bin_plugin.h"

namespace flutter_bin {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(FlutterBinPlugin, GetPlatformVersion) {
  FlutterBinPlugin plugin;
  // Save the reply value from the success callback.
  std::string result_string;
  plugin.HandleMethodCall(
      MethodCall("getPlatformVersion", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&result_string](const EncodableValue* result) {
            result_string = std::get<std::string>(*result);
          },
          nullptr, nullptr));

  // Since the exact string varies by host, just ensure that it's a string
  // with the expected format.
  EXPECT_TRUE(result_string.rfind("Windows ", 0) == 0);
}

}  // namespace test
}  // namespace flutter_bin

```

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

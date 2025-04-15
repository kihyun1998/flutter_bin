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
    } else {
      try {
        final version = await _flutterBinPlugin.getBinaryFileVersion(filePath);
        fileVersion = version ?? 'No version information available';
      } on PlatformException catch (e) {
        fileVersion = 'Error: ${e.message}';
      }
    }

    if (!mounted) return;

    setState(() {
      _fileVersion = fileVersion;
    });
  }

  // Method 2: Get version using FilePicker
  Future<void> _pickFileAndGetVersion() async {
    String fileVersion;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        _filePathController.text = filePath; // Update the text field

        final version = await _flutterBinPlugin.getBinaryFileVersion(filePath);
        fileVersion = version ?? 'No version information available';
      } else {
        fileVersion = 'File selection canceled';
      }
    } on PlatformException catch (e) {
      fileVersion = 'Error: ${e.message}';
    }

    if (!mounted) return;

    setState(() {
      _fileVersion = fileVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Binary File Version Plugin'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Method 1: Manual file path input
              const Text('Method 1: Enter file path manually',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _filePathController,
                decoration: const InputDecoration(
                  hintText: 'C:\\path\\to\\file.exe',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _getFileVersionFromPath,
                child: const Text('Get Version from Path'),
              ),
              const SizedBox(height: 20),

              // Method 2: FilePicker
              const Text('Method 2: Use FilePicker',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: _pickFileAndGetVersion,
                child: const Text('Select File Using FilePicker'),
              ),
              const SizedBox(height: 20),

              // Result display
              const Text('Result:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('File version: $_fileVersion'),
            ],
          ),
        ),
      ),
    );
  }
}

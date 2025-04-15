import 'dart:async';

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

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickFileAndGetVersion() async {
    String fileVersion;
    try {
      final version = await _flutterBinPlugin.pickFileAndGetVersion();
      fileVersion = version ?? 'No version information available';
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('File version: $_fileVersion'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickFileAndGetVersion,
                child: const Text('Select Binary File'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

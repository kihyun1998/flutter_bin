import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bin/flutter_bin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BinaryMetadataScreen(),
    );
  }
}

class BinaryMetadataScreen extends StatefulWidget {
  const BinaryMetadataScreen({super.key});

  @override
  State<BinaryMetadataScreen> createState() => _BinaryMetadataScreenState();
}

class _BinaryMetadataScreenState extends State<BinaryMetadataScreen> {
  final FlutterBin _plugin = FlutterBin();
  String? _filePath;
  String _version = '';
  BinaryFileMetadata? _metadata;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path!;
        _version = '';
        _metadata = null;
      });
    }
  }

  Future<void> _getVersion() async {
    if (_filePath == null) return;
    try {
      final version = await _plugin.getBinaryFileVersion(_filePath!);
      setState(() {
        _version = version ?? 'No version info';
        _metadata = null;
      });
    } on PlatformException catch (e) {
      setState(() {
        _version = 'Error: ${e.message}';
        _metadata = null;
      });
    }
  }

  Future<void> _getMetadata() async {
    if (_filePath == null) return;
    try {
      final metadata = await _plugin.getBinaryFileMetadata(_filePath!);
      setState(() {
        _version =
            metadata.version.isNotEmpty ? metadata.version : 'No version info';
        _metadata = metadata;
      });
    } on PlatformException catch (e) {
      setState(() {
        _version = 'Error: ${e.message}';
        _metadata = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Binary Metadata')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Select Binary File'),
            ),
            const SizedBox(height: 8),
            Text(_filePath ?? 'No file selected'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _getVersion,
                  child: const Text('Get Version'),
                ),
                ElevatedButton(
                  onPressed: _getMetadata,
                  child: const Text('Get Full Metadata'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_version.isNotEmpty)
              Text('Version: $_version',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_metadata != null) ...[
              const SizedBox(height: 16),
              const Text('Metadata:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _buildMetadataTable(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataTable() {
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      border: TableBorder.all(color: Colors.grey),
      children: [
        _buildRow('Product Name', _metadata!.productName),
        _buildRow('Description', _metadata!.fileDescription),
        _buildRow('Copyright', _metadata!.legalCopyright),
        _buildRow('Original Filename', _metadata!.originalFilename),
        _buildRow('Company', _metadata!.companyName),
      ],
    );
  }

  TableRow _buildRow(String label, String value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(value.isNotEmpty ? value : 'N/A'),
      ),
    ]);
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bin/flutter_bin.dart';
import 'package:flutter_bin/pe.dart';

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
  List<PeVersionResource> _peResources = const [];
  PeVersionResource? _peSelected;
  String _peStatus = '';
  String _osOriginalFilename = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path!;
        _version = '';
        _metadata = null;
        _peResources = const [];
        _peSelected = null;
        _peStatus = '';
        _osOriginalFilename = '';
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

  /// The image view: parses the PE file itself, so it also reads binaries whose
  /// version resource the OS cannot find. Reads the OS view alongside it, since
  /// the interesting part is where the two disagree — see the README.
  Future<void> _getPeImageView() async {
    if (_filePath == null) return;
    final resources = await readPeVersionResources(_filePath!);
    final osView = await _plugin.getBinaryFileMetadata(_filePath!);
    setState(() {
      _peResources = resources;
      _peSelected = selectPeVersionResource(resources);
      _osOriginalFilename = osView.originalFilename;
      _peStatus = resources.isEmpty
          ? 'Not a PE image, or no version resource'
          : '${resources.length} version resource(s) in the image';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Binary Metadata')),
      // The image view can list many keys across several resources, so the whole
      // report scrolls rather than clipping.
      body: SingleChildScrollView(
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
                ElevatedButton(
                  onPressed: _getPeImageView,
                  child: const Text('Read PE Image View'),
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
            if (_peStatus.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('PE image view: $_peStatus',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_peResources.isNotEmpty) _buildPeTable(),
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

  Widget _buildPeTable() {
    final selected = _peSelected;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      border: TableBorder.all(color: Colors.grey),
      children: [
        // Where the two views disagree: the OS follows MUI satellites (and reads
        // nothing at all when the resource entry is name-stored), the image view
        // reports what the binary carries.
        _buildSectionRow('The same field, both views'),
        _buildRow(
            'originalFilename (OS view)',
            _osOriginalFilename.isEmpty
                ? '(nothing read)'
                : _osOriginalFilename),
        _buildRow('originalFilename (image view)',
            selected?.value('OriginalFilename') ?? ''),

        if (selected != null) ...[
          // What a caller reusing code written against getBinaryFileMetadata
          // would see if it fed the image view through toBinaryFileMetadata().
          _buildSectionRow('Selected resource, mapped to BinaryFileMetadata'),
          ..._buildMappedRows(selected.toBinaryFileMetadata()),
        ],

        for (final resource in _peResources) ...[
          // '#1' for the conventional numeric entry, a name string otherwise —
          // the latter is what the OS view cannot find. The selected one is what
          // the singular readPeVersionResource returns.
          _buildSectionRow(
            'Resource ${resource.resourceName}, language ${resource.languageId}'
            '${resource == selected ? '  —  selected' : ''}',
          ),
          _buildRow('File Version', resource.fixedFileVersion),
          _buildRow('Product Version', resource.fixedProductVersion),
          for (final table in resource.stringTables) ...[
            _buildSectionRow(
              'StringFileInfo \\${table.languageCodePage}'
              '  —  ${table.values.length} keys',
            ),
            for (final entry in table.values.entries)
              _buildRow(entry.key, entry.value),
          ],
        ],
      ],
    );
  }

  List<TableRow> _buildMappedRows(BinaryFileMetadata metadata) => [
        _buildRow('version', metadata.version),
        _buildRow('productName', metadata.productName),
        _buildRow('companyName', metadata.companyName),
        _buildRow('originalFilename', metadata.originalFilename),
        _buildRow('fileDescription', metadata.fileDescription),
        _buildRow('legalCopyright', metadata.legalCopyright),
      ];

  /// A full-width heading between groups of rows.
  TableRow _buildSectionRow(String title) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox.shrink(),
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
        child: SelectableText(value.isNotEmpty ? value : 'N/A'),
      ),
    ]);
  }
}

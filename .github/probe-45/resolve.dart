import 'package:flutter_bin/src/macos/info_plist_reader.dart';

void main(List<String> paths) {
  final reader = MacOSInfoPlistReader();
  for (final path in paths) {
    final id = reader.readMetadata(path)['productName'] ?? '';
    print('flutter_bin\t$path\t${resolveInfoPlistPath(path)}\t${id.isEmpty ? '-' : id}');
  }
}

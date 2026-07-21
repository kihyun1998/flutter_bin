import 'package:flutter_bin/src/macos/info_plist_reader.dart';
import 'package:test/test.dart';

void main() {
  group('resolveInfoPlistPath', () {
    test('.app bundle root appends Contents/Info.plist', () {
      expect(
        resolveInfoPlistPath('/Applications/Foo.app'),
        '/Applications/Foo.app/Contents/Info.plist',
      );
    });

    test('.app bundle root with a trailing slash', () {
      expect(
        resolveInfoPlistPath('/Applications/Foo.app/'),
        '/Applications/Foo.app/Contents/Info.plist',
      );
    });

    test('already-inside-Contents path round-trips to the same plist', () {
      // A path already pointing at Contents/Info.plist must resolve to itself,
      // not double up the Contents segment. Mirrors the Swift
      // `pathComponents.contains("Contents")` branch.
      expect(
        resolveInfoPlistPath('/Applications/Foo.app/Contents/Info.plist'),
        '/Applications/Foo.app/Contents/Info.plist',
      );
    });

    test('non-.app path is treated as the bundle root', () {
      expect(
        resolveInfoPlistPath('/opt/mytool'),
        '/opt/mytool/Contents/Info.plist',
      );
    });

    test('parity: a deep path inside a bundle reproduces the Swift quirk', () {
      // The Swift code deletes the last two path components whenever "Contents"
      // appears anywhere, so a deep executable path yields a doubled Contents.
      // Locked in to guarantee byte-for-byte parity with the old plugin.
      expect(
        resolveInfoPlistPath('/Applications/Foo.app/Contents/MacOS/Foo'),
        '/Applications/Foo.app/Contents/Contents/Info.plist',
      );
    });
  });
}

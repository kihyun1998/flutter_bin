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

    test('a path inside the bundle resolves to the bundle root plist', () {
      expect(
        resolveInfoPlistPath('/Applications/Foo.app/Contents/MacOS/Foo'),
        '/Applications/Foo.app/Contents/Info.plist',
      );
      expect(
        resolveInfoPlistPath('/Applications/Foo.app/Contents'),
        '/Applications/Foo.app/Contents/Info.plist',
      );
      expect(
        resolveInfoPlistPath(
            '/Applications/Foo.app/Contents/Resources/en.lproj/x.strings'),
        '/Applications/Foo.app/Contents/Info.plist',
      );
    });

    test('a Contents folder above the bundle is not part of the bundle', () {
      expect(
        resolveInfoPlistPath('/Users/me/Contents/Foo.app'),
        '/Users/me/Contents/Foo.app/Contents/Info.plist',
      );
    });

    test('a nested .app resolves to the innermost bundle', () {
      expect(
        resolveInfoPlistPath('/Applications/Outer.app/Contents/Helper.app'),
        '/Applications/Outer.app/Contents/Helper.app/Contents/Info.plist',
      );
      expect(
        resolveInfoPlistPath('/Applications/Outer.app/Contents/Frameworks/'
            'Helper.app/Contents/MacOS/Helper'),
        '/Applications/Outer.app/Contents/Frameworks/Helper.app/Contents/'
        'Info.plist',
      );
    });
  });
}

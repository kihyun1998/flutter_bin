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

import 'package:flutter_bin/flutter_bin_method_channel.dart';
import 'package:flutter_bin/flutter_bin_platform_interface.dart';
import 'package:flutter_bin/models/binary_file_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBinPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBinPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> getBinaryFileVersion(String filePath) {
    // TODO: implement getBinaryFileVersion
    throw UnimplementedError();
  }

  @override
  Future<String?> pickFileAndGetVersion() {
    // TODO: implement pickFileAndGetVersion
    throw UnimplementedError();
  }

  @override
  Future<BinaryFileMetadata> getBinaryFileMetadata(String filePath) {
    // TODO: implement getBinaryFileMetadata
    throw UnimplementedError();
  }
}

void main() {
  final FlutterBinPlatform initialPlatform = FlutterBinPlatform.instance;

  test('$MethodChannelFlutterBin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterBin>());
  });
}

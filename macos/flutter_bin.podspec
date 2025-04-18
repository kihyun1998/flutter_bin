#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_bin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_bin'
  s.version          = '1.1.0'
  s.summary          = 'A Flutter plugin to retrieve metadata from binary files on desktop platforms'
  s.description      = <<-DESC
A Flutter plugin to retrieve metadata from binary files (executable files) on desktop platforms. 
Currently supports retrieving file version and other metadata on Windows and macOS.
                       DESC
  s.homepage         = 'https://github.com/kihyun1998/flutter_bin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'kihyun1998' => 'github.com/kihyun1998' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  # Include privacy manifest file
  s.resource_bundles = {'flutter_bin_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
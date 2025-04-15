#ifndef FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <string>

namespace flutter_bin {

class FlutterBinPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterBinPlugin();

  virtual ~FlutterBinPlugin();

  // Disallow copy and assign.
  FlutterBinPlugin(const FlutterBinPlugin&) = delete;
  FlutterBinPlugin& operator=(const FlutterBinPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
      
 private:
  // Methods to handle specific platform calls
  std::string GetBinaryFileVersion(const std::string& file_path);
  std::string PickFileAndGetVersion();
};

}  // namespace flutter_bin

#endif  // FLUTTER_PLUGIN_FLUTTER_BIN_PLUGIN_H_
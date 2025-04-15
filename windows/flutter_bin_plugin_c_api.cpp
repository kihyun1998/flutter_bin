#include "include/flutter_bin/flutter_bin_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_bin_plugin.h"

void FlutterBinPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_bin::FlutterBinPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

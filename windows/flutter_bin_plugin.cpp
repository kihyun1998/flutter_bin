#include "flutter_bin_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For version info
#include <winver.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

// Need to link with Version.lib
#pragma comment(lib, "Version.lib")

namespace flutter_bin {

// static
void FlutterBinPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_bin",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterBinPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterBinPlugin::FlutterBinPlugin() {}

FlutterBinPlugin::~FlutterBinPlugin() {}

void FlutterBinPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getBinaryFileVersion") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    
    if (arguments) {
      auto file_path_it = arguments->find(flutter::EncodableValue("filePath"));
      if (file_path_it != arguments->end()) {
        const std::string& file_path = std::get<std::string>(file_path_it->second);
        std::string version = GetBinaryFileVersion(file_path);
        if (!version.empty()) {
          result->Success(flutter::EncodableValue(version));
        } else {
          result->Success(nullptr);
        }
      } else {
        result->Error("INVALID_ARGUMENT", "Argument 'filePath' not found");
      }
    } else {
      result->Error("INVALID_ARGUMENT", "Arguments must be a map");
    }
  } else {
    result->NotImplemented();
  }
}

std::string FlutterBinPlugin::GetBinaryFileVersion(const std::string& file_path) {
  // Convert from UTF-8 to wide string
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, NULL, 0);
  std::wstring wide_path(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, &wide_path[0], size_needed);

  // Check if file exists
  DWORD file_attributes = GetFileAttributesW(wide_path.c_str());
  if (file_attributes == INVALID_FILE_ATTRIBUTES) {
    // File doesn't exist or is inaccessible
    return "";
  }

  // Get the size of the version info
  DWORD dummy;
  DWORD version_info_size = GetFileVersionInfoSizeW(wide_path.c_str(), &dummy);
  if (version_info_size == 0) {
    // Could not get version info size
    return "";
  }

  // Allocate memory for the version info
  std::vector<BYTE> version_info(version_info_size);
  if (!GetFileVersionInfoW(wide_path.c_str(), 0, version_info_size, version_info.data())) {
    // Could not get version info
    return "";
  }

  // Get the fixed file info
  VS_FIXEDFILEINFO* fixed_file_info = nullptr;
  UINT len = 0;
  if (!VerQueryValueW(version_info.data(), L"\\", (LPVOID*)&fixed_file_info, &len)) {
    // Could not get fixed file info
    return "";
  }

  // Extract the version
  DWORD major = HIWORD(fixed_file_info->dwFileVersionMS);
  DWORD minor = LOWORD(fixed_file_info->dwFileVersionMS);
  DWORD build = HIWORD(fixed_file_info->dwFileVersionLS);
  DWORD revision = LOWORD(fixed_file_info->dwFileVersionLS);

  // Format the version string
  std::ostringstream version_stream;
  version_stream << major << "." << minor << "." << build << "." << revision;
  return version_stream.str();
}

}  // namespace flutter_bin
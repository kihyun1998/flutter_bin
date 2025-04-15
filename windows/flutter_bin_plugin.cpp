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
#include <string>

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
  } 
  else if (method_call.method_name().compare("getBinaryFileMetadata") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    
    if (arguments) {
      auto file_path_it = arguments->find(flutter::EncodableValue("filePath"));
      if (file_path_it != arguments->end()) {
        const std::string& file_path = std::get<std::string>(file_path_it->second);
        flutter::EncodableMap metadata = GetBinaryFileMetadata(file_path);
        result->Success(flutter::EncodableValue(metadata));
      } else {
        result->Error("INVALID_ARGUMENT", "Argument 'filePath' not found");
      }
    } else {
      result->Error("INVALID_ARGUMENT", "Arguments must be a map");
    }
  }
  else {
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

// Helper function to convert Wide String to UTF-8
std::string WideStringToUtf8(const wchar_t* wide_str, int length = -1) {
  if (!wide_str) return "";
  
  // Calculate the required buffer size
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide_str, length, NULL, 0, NULL, NULL);
  if (size_needed <= 0) return "";

  // Allocate the buffer and convert
  std::string utf8_str(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide_str, length, &utf8_str[0], size_needed, NULL, NULL);
  
  // If we got a null-terminated string with explicit length, remove the null terminator from the result
  if (length == -1 && !utf8_str.empty() && utf8_str.back() == '\0') {
    utf8_str.pop_back();
  }
  
  return utf8_str;
}

// Helper to get a string value from version info
std::string GetVersionInfoString(const std::vector<BYTE>& version_info, const std::wstring& sub_block) {
  UINT size = 0;
  LPVOID buffer = nullptr;
  
  // First try to get string with default language
  std::wstring query = L"\\StringFileInfo\\040904B0\\" + sub_block;
  if (VerQueryValueW(version_info.data(), query.c_str(), &buffer, &size) && size > 0 && buffer != nullptr) {
    return WideStringToUtf8(static_cast<const wchar_t*>(buffer));
  }
  
  // If that fails, try to find any available language
  struct LANGANDCODEPAGE {
    WORD language;
    WORD code_page;
  } *translate;
  
  UINT translate_size = 0;
  if (!VerQueryValueW(version_info.data(), L"\\VarFileInfo\\Translation", 
                     reinterpret_cast<LPVOID*>(&translate), &translate_size)) {
    return "";
  }
  
  size_t count = translate_size / sizeof(LANGANDCODEPAGE);
  for (size_t i = 0; i < count; ++i) {
    // Format the language and codepage as a string for the query
    wchar_t sub_block_lang[50];
    swprintf_s(sub_block_lang, L"\\StringFileInfo\\%04x%04x\\%s", 
              translate[i].language, translate[i].code_page, sub_block.c_str());
    
    if (VerQueryValueW(version_info.data(), sub_block_lang, &buffer, &size) && size > 0 && buffer != nullptr) {
      return WideStringToUtf8(static_cast<const wchar_t*>(buffer));
    }
  }
  
  return "";
}

flutter::EncodableMap FlutterBinPlugin::GetBinaryFileMetadata(const std::string& file_path) {
  flutter::EncodableMap metadata;
  
  // Convert from UTF-8 to wide string
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, NULL, 0);
  std::wstring wide_path(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, &wide_path[0], size_needed);

  // Check if file exists
  DWORD file_attributes = GetFileAttributesW(wide_path.c_str());
  if (file_attributes == INVALID_FILE_ATTRIBUTES) {
    // File doesn't exist or is inaccessible
    return metadata;
  }

  // Get the size of the version info
  DWORD dummy;
  DWORD version_info_size = GetFileVersionInfoSizeW(wide_path.c_str(), &dummy);
  if (version_info_size == 0) {
    // Could not get version info size
    return metadata;
  }

  // Allocate memory for the version info
  std::vector<BYTE> version_info(version_info_size);
  if (!GetFileVersionInfoW(wide_path.c_str(), 0, version_info_size, version_info.data())) {
    // Could not get version info
    return metadata;
  }

  // Get the fixed file info for version
  VS_FIXEDFILEINFO* fixed_file_info = nullptr;
  UINT len = 0;
  if (VerQueryValueW(version_info.data(), L"\\", (LPVOID*)&fixed_file_info, &len)) {
    // Extract the version
    DWORD major = HIWORD(fixed_file_info->dwFileVersionMS);
    DWORD minor = LOWORD(fixed_file_info->dwFileVersionMS);
    DWORD build = HIWORD(fixed_file_info->dwFileVersionLS);
    DWORD revision = LOWORD(fixed_file_info->dwFileVersionLS);

    // Format the version string
    std::ostringstream version_stream;
    version_stream << major << "." << minor << "." << build << "." << revision;
    metadata[flutter::EncodableValue("version")] = flutter::EncodableValue(version_stream.str());
  }

  // Get string values from version info
  metadata[flutter::EncodableValue("productName")] = 
      flutter::EncodableValue(GetVersionInfoString(version_info, L"ProductName")); 
  
  metadata[flutter::EncodableValue("fileDescription")] = 
      flutter::EncodableValue(GetVersionInfoString(version_info, L"FileDescription"));
  
  metadata[flutter::EncodableValue("legalCopyright")] = 
      flutter::EncodableValue(GetVersionInfoString(version_info, L"LegalCopyright"));
  
  metadata[flutter::EncodableValue("originalFilename")] = 
      flutter::EncodableValue(GetVersionInfoString(version_info, L"OriginalFilename"));
  
  metadata[flutter::EncodableValue("companyName")] = 
      flutter::EncodableValue(GetVersionInfoString(version_info, L"CompanyName"));

  return metadata;
}

}  // namespace flutter_bin
#include "flutter_bin_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For version info
#include <winver.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

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

namespace {

// Extracts the required string "filePath" argument from a method call. On
// success, writes it to *file_path and returns true. On any failure (arguments
// not a map, key missing, or value not a string) sends an INVALID_ARGUMENT
// error via *result and returns false. Using std::get_if (not std::get) keeps
// a non-string value from throwing std::bad_variant_access and crashing.
bool TryGetFilePath(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    flutter::MethodResult<flutter::EncodableValue>* result,
    std::string* file_path) {
  const auto* arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!arguments) {
    result->Error("INVALID_ARGUMENT", "Arguments must be a map");
    return false;
  }

  auto it = arguments->find(flutter::EncodableValue("filePath"));
  if (it == arguments->end()) {
    result->Error("INVALID_ARGUMENT", "Argument 'filePath' not found");
    return false;
  }

  const auto* value = std::get_if<std::string>(&it->second);
  if (!value) {
    result->Error("INVALID_ARGUMENT", "Argument 'filePath' must be a string");
    return false;
  }

  *file_path = *value;
  return true;
}

}  // namespace

void FlutterBinPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (method_call.method_name().compare("getBinaryFileVersion") == 0) {
    std::string file_path;
    if (!TryGetFilePath(method_call, result.get(), &file_path)) {
      return;
    }

    std::string version = GetBinaryFileVersion(file_path);
    if (!version.empty()) {
      result->Success(flutter::EncodableValue(version));
    } else {
      // No-arg Success() sends a real null; Success(nullptr) would
      // silently decode to EncodableValue(false) (a bool) instead.
      result->Success();
    }
  }
  else if (method_call.method_name().compare("getBinaryFileMetadata") == 0) {
    std::string file_path;
    if (!TryGetFilePath(method_call, result.get(), &file_path)) {
      return;
    }

    std::map<std::string, std::string> metadata_map =
        GetBinaryFileMetadata(file_path);

    // Convert std::map to flutter::EncodableMap
    flutter::EncodableMap result_map;
    for (const auto& pair : metadata_map) {
      result_map[flutter::EncodableValue(pair.first)] =
          flutter::EncodableValue(pair.second);
    }

    result->Success(flutter::EncodableValue(result_map));
  }
  else {
    result->NotImplemented();
  }
}

namespace {

// Converts a UTF-16 wide string to UTF-8. With the default length of -1 the
// input is treated as null-terminated and the trailing null is trimmed.
std::string WideStringToUtf8(const wchar_t* wide_str, int length = -1) {
  if (!wide_str) return "";

  int size_needed =
      WideCharToMultiByte(CP_UTF8, 0, wide_str, length, NULL, 0, NULL, NULL);
  if (size_needed <= 0) return "";

  std::string utf8_str(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide_str, length, &utf8_str[0], size_needed,
                      NULL, NULL);

  if (length == -1 && !utf8_str.empty() && utf8_str.back() == '\0') {
    utf8_str.pop_back();
  }
  return utf8_str;
}

// Loads the raw version-info block for a file. Returns std::nullopt when the
// file is missing/inaccessible or carries no version resource. This is the
// shared preamble both public methods used to duplicate verbatim.
std::optional<std::vector<BYTE>> LoadVersionInfo(const std::string& file_path) {
  int size_needed =
      MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, NULL, 0);
  std::wstring wide_path(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, &wide_path[0],
                      size_needed);

  if (GetFileAttributesW(wide_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return std::nullopt;
  }

  DWORD dummy;
  DWORD version_info_size = GetFileVersionInfoSizeW(wide_path.c_str(), &dummy);
  if (version_info_size == 0) {
    return std::nullopt;
  }

  std::vector<BYTE> version_info(version_info_size);
  if (!GetFileVersionInfoW(wide_path.c_str(), 0, version_info_size,
                           version_info.data())) {
    return std::nullopt;
  }
  return version_info;
}

// Formats the fixed file info as a semantic version "major.minor.patch".
// The Windows file version is major.minor.build.revision; the trailing revision
// is dropped so the value matches semver across platforms (see #5 / ADR-0003).
std::string FormatFixedVersion(const VS_FIXEDFILEINFO& info) {
  std::ostringstream stream;
  stream << HIWORD(info.dwFileVersionMS) << "." << LOWORD(info.dwFileVersionMS)
         << "." << HIWORD(info.dwFileVersionLS);
  return stream.str();
}

// Reads a named string (e.g. "ProductName") from a version-info block, trying
// the default US-English language first and then any available translation.
std::string GetVersionInfoString(const std::vector<BYTE>& version_info,
                                 const std::wstring& sub_block) {
  UINT size = 0;
  LPVOID buffer = nullptr;

  std::wstring query = L"\\StringFileInfo\\040904B0\\" + sub_block;
  if (VerQueryValueW(version_info.data(), query.c_str(), &buffer, &size) &&
      size > 0 && buffer != nullptr) {
    return WideStringToUtf8(static_cast<const wchar_t*>(buffer));
  }

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
    wchar_t sub_block_lang[50];
    swprintf_s(sub_block_lang, L"\\StringFileInfo\\%04x%04x\\%s",
               translate[i].language, translate[i].code_page,
               sub_block.c_str());

    if (VerQueryValueW(version_info.data(), sub_block_lang, &buffer, &size) &&
        size > 0 && buffer != nullptr) {
      return WideStringToUtf8(static_cast<const wchar_t*>(buffer));
    }
  }

  return "";
}

}  // namespace

std::string FlutterBinPlugin::GetBinaryFileVersion(const std::string& file_path) {
  auto version_info = LoadVersionInfo(file_path);
  if (!version_info) {
    return "";
  }

  VS_FIXEDFILEINFO* fixed_file_info = nullptr;
  UINT len = 0;
  if (!VerQueryValueW(version_info->data(), L"\\", (LPVOID*)&fixed_file_info,
                      &len) ||
      fixed_file_info == nullptr) {
    return "";
  }

  return FormatFixedVersion(*fixed_file_info);
}

std::map<std::string, std::string> FlutterBinPlugin::GetBinaryFileMetadata(const std::string& file_path) {
  std::map<std::string, std::string> metadata;

  auto version_info = LoadVersionInfo(file_path);
  if (!version_info) {
    return metadata;
  }

  VS_FIXEDFILEINFO* fixed_file_info = nullptr;
  UINT len = 0;
  if (VerQueryValueW(version_info->data(), L"\\", (LPVOID*)&fixed_file_info,
                     &len) &&
      fixed_file_info != nullptr) {
    metadata["version"] = FormatFixedVersion(*fixed_file_info);
  }

  metadata["productName"] = GetVersionInfoString(*version_info, L"ProductName");
  metadata["fileDescription"] =
      GetVersionInfoString(*version_info, L"FileDescription");
  metadata["legalCopyright"] =
      GetVersionInfoString(*version_info, L"LegalCopyright");
  metadata["originalFilename"] =
      GetVersionInfoString(*version_info, L"OriginalFilename");
  metadata["companyName"] = GetVersionInfoString(*version_info, L"CompanyName");

  return metadata;
}

}  // namespace flutter_bin
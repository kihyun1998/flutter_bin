#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <regex>
#include <set>
#include <string>
#include <variant>

#include "flutter_bin_plugin.h"

namespace flutter_bin {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

// Captures the outcome of a single HandleMethodCall invocation so tests can
// assert on observable behavior (success vs error) rather than internals.
struct CallOutcome {
  bool succeeded = false;
  bool errored = false;
  std::string error_code;
  EncodableValue value;
};

CallOutcome Invoke(FlutterBinPlugin& plugin,
                   const std::string& method,
                   std::unique_ptr<EncodableValue> arguments) {
  CallOutcome outcome;
  auto result = std::make_unique<MethodResultFunctions<>>(
      [&outcome](const EncodableValue* value) {
        outcome.succeeded = true;
        if (value) outcome.value = *value;
      },
      [&outcome](const std::string& code, const std::string& /*message*/,
                 const EncodableValue* /*details*/) {
        outcome.errored = true;
        outcome.error_code = code;
      },
      nullptr);
  plugin.HandleMethodCall(MethodCall(method, std::move(arguments)),
                          std::move(result));
  return outcome;
}

std::unique_ptr<EncodableValue> FilePathArgs(const std::string& path) {
  return std::make_unique<EncodableValue>(
      EncodableMap{{EncodableValue("filePath"), EncodableValue(path)}});
}

}  // namespace

// Characterization: asking for the version of a path that does not exist
// succeeds with a null result (not an error). This pins current behavior so
// the upcoming refactors (#1, #2) can't change it unnoticed.
TEST(FlutterBinPlugin, VersionOfMissingFileIsNullSuccess) {
  FlutterBinPlugin plugin;
  auto outcome =
      Invoke(plugin, "getBinaryFileVersion", FilePathArgs("Z:/no/such/file.exe"));

  EXPECT_TRUE(outcome.succeeded);
  EXPECT_FALSE(outcome.errored);
  EXPECT_TRUE(outcome.value.IsNull());
}

// Characterization: metadata of a missing file succeeds with an (empty) map.
TEST(FlutterBinPlugin, MetadataOfMissingFileIsEmptyMapSuccess) {
  FlutterBinPlugin plugin;
  auto outcome = Invoke(plugin, "getBinaryFileMetadata",
                        FilePathArgs("Z:/no/such/file.exe"));

  EXPECT_TRUE(outcome.succeeded);
  EXPECT_FALSE(outcome.errored);
  ASSERT_TRUE(std::holds_alternative<EncodableMap>(outcome.value));
  EXPECT_TRUE(std::get<EncodableMap>(outcome.value).empty());
}

// Issue #1: a filePath argument that is present but not a string must be
// rejected with INVALID_ARGUMENT, not crash the plugin. Before the fix this
// path calls std::get<std::string> on a non-string variant, which throws
// std::bad_variant_access and terminates the process.
TEST(FlutterBinPlugin, NonStringFilePathIsInvalidArgument) {
  FlutterBinPlugin plugin;
  auto args = std::make_unique<EncodableValue>(
      EncodableMap{{EncodableValue("filePath"), EncodableValue(42)}});
  auto outcome = Invoke(plugin, "getBinaryFileVersion", std::move(args));

  EXPECT_FALSE(outcome.succeeded);
  EXPECT_TRUE(outcome.errored);
  EXPECT_EQ(outcome.error_code, "INVALID_ARGUMENT");
}

// Issue #1: a missing filePath key is rejected with INVALID_ARGUMENT.
TEST(FlutterBinPlugin, MissingFilePathIsInvalidArgument) {
  FlutterBinPlugin plugin;
  auto args = std::make_unique<EncodableValue>(EncodableMap{});
  auto outcome = Invoke(plugin, "getBinaryFileMetadata", std::move(args));

  EXPECT_TRUE(outcome.errored);
  EXPECT_EQ(outcome.error_code, "INVALID_ARGUMENT");
}

// Issue #1: arguments that are not a map are rejected with INVALID_ARGUMENT.
TEST(FlutterBinPlugin, NonMapArgumentsIsInvalidArgument) {
  FlutterBinPlugin plugin;
  auto args = std::make_unique<EncodableValue>(EncodableValue("not a map"));
  auto outcome = Invoke(plugin, "getBinaryFileVersion", std::move(args));

  EXPECT_TRUE(outcome.errored);
  EXPECT_EQ(outcome.error_code, "INVALID_ARGUMENT");
}

// Characterization: an unknown method is reported as not-implemented, i.e.
// neither success nor error is delivered.
TEST(FlutterBinPlugin, UnknownMethodIsNotImplemented) {
  FlutterBinPlugin plugin;
  auto outcome = Invoke(plugin, "getPlatformVersion",
                        std::make_unique<EncodableValue>());

  EXPECT_FALSE(outcome.succeeded);
  EXPECT_FALSE(outcome.errored);
}

// Characterization (success path): a real system DLL yields a 4-part numeric
// version and stable, locale-independent metadata. This pins the loader and
// formatter behavior before the #2 refactor extracts LoadVersionInfo /
// FormatFixedVersion, so an accidental regression there can't slip through.
TEST(FlutterBinPlugin, RealSystemDllHasVersionAndMetadata) {
  FlutterBinPlugin plugin;
  const std::string kDll = "C:/Windows/System32/kernel32.dll";
  const std::regex kFourPartVersion(R"(^\d+\.\d+\.\d+\.\d+$)");

  auto v = Invoke(plugin, "getBinaryFileVersion", FilePathArgs(kDll));
  ASSERT_TRUE(std::holds_alternative<std::string>(v.value));
  EXPECT_TRUE(std::regex_match(std::get<std::string>(v.value), kFourPartVersion));

  auto m = Invoke(plugin, "getBinaryFileMetadata", FilePathArgs(kDll));
  ASSERT_TRUE(std::holds_alternative<EncodableMap>(m.value));
  const auto& map = std::get<EncodableMap>(m.value);
  auto field = [&](const char* key) -> std::string {
    auto it = map.find(EncodableValue(key));
    return it == map.end() ? std::string() : std::get<std::string>(it->second);
  };

  EXPECT_TRUE(std::regex_match(field("version"), kFourPartVersion));
  EXPECT_EQ(field("companyName"), "Microsoft Corporation");
  EXPECT_EQ(field("originalFilename"), "kernel32");
}

// Issue #4: the metadata map must carry exactly the canonical channel keys.
// This is the Windows half of the cross-language key contract whose source of
// truth is the Dart BinaryFileMetadataJsonKey enum (see the Dart test
// test/models/binary_file_metadata_test.dart and docs/method-channel-contract.md).
TEST(FlutterBinPlugin, MetadataKeysMatchTheChannelContract) {
  FlutterBinPlugin plugin;
  auto m = Invoke(plugin, "getBinaryFileMetadata",
                  FilePathArgs("C:/Windows/System32/kernel32.dll"));
  ASSERT_TRUE(std::holds_alternative<EncodableMap>(m.value));

  std::set<std::string> keys;
  for (const auto& kv : std::get<EncodableMap>(m.value)) {
    keys.insert(std::get<std::string>(kv.first));
  }

  const std::set<std::string> expected = {
      "version",        "productName",      "fileDescription",
      "legalCopyright", "originalFilename", "companyName"};
  EXPECT_EQ(keys, expected);
}

}  // namespace test
}  // namespace flutter_bin

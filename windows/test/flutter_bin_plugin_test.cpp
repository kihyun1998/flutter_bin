#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
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

}  // namespace test
}  // namespace flutter_bin

import Cocoa
import FlutterMacOS

public class FlutterBinPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_bin", binaryMessenger: registrar.messenger)
    let instance = FlutterBinPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let filePath = args["filePath"] as? String else{
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing or invalid 'filePath'", details: nil))
      return
    }

    switch call.method {
    case "getBinaryFileVersion":
      result(getBinaryFileVersion(filePath: filePath))
    case "getBinaryFileMetadata":
      result(getBinaryFileMetadata(filePath: filePath))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getBinaryFileVersion(filePath: String) -> String? {
    let infoPlistPath = resolveInfoPlistPath(from: filePath)
    guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
          let version = infoPlist["CFBundleShortVersionString"] as? String else {
      return nil
    }
    return version
  }

  private func getBinaryFileMetadata(filePath: String) -> [String: String] {
    var metadata: [String: String] = [:]

    let infoPlistPath = resolveInfoPlistPath(from: filePath)
    guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) else {
      return metadata
    }

    metadata["version"] = infoPlist["CFBundleShortVersionString"] as? String ?? ""
    metadata["productName"] = infoPlist["CFBundleName"] as? String ?? ""
    metadata["fileDescription"] = infoPlist["CFBundleGetInfoString"] as? String ?? ""
    metadata["legalCopyright"] = infoPlist["NSHumanReadableCopyright"] as? String ?? ""
    metadata["originalFilename"] = infoPlist["CFBundleExecutable"] as? String ?? ""
    metadata["companyName"] = "" // Not typically available in macOS

    return metadata
  }

  /// Resolves the actual Info.plist path based on input path type
  private func resolveInfoPlistPath(from filePath: String) -> String {
    let fileURL = URL(fileURLWithPath: filePath)

    // If it's a .app bundle, go to Contents/Info.plist
    if fileURL.pathExtension == "app" || filePath.contains(".app/") {
      let appPath = fileURL.pathComponents.contains("Contents")
        ? fileURL.deletingLastPathComponent().deletingLastPathComponent()
        : fileURL
      return appPath.appendingPathComponent("Contents/Info.plist").path
    }

    // Otherwise try to treat filePath as direct .plist for standalone binaries
    return filePath + "/Contents/Info.plist"
  }
}

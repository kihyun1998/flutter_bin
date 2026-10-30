import Foundation
// Run as a bundle's executable: print the bundle macOS assigns to this process.
// Run with path arguments: print what Bundle(path:) makes of each.
let args = CommandLine.arguments.dropFirst()
if args.isEmpty {
  print("main\t\(Bundle.main.bundlePath)\t\(Bundle.main.bundleIdentifier ?? "-")")
} else {
  for path in args {
    let b = Bundle(path: path)
    print("Bundle(path:)\t\(path)\t\(b?.bundlePath ?? "nil")\t\(b?.bundleIdentifier ?? "-")")
  }
}

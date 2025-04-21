## 1.1.0

* Added macOS platform support:
  * Retrieve file version information from macOS binary files
  * Extract metadata from Info.plist files in macOS applications
  * Support for both .app bundles and standalone binaries

## 1.0.0

Initial release of the flutter_bin plugin.

* Features:
  * Get basic version information from binary files on Windows
  * Get comprehensive metadata from Windows binary files including:
    * Product name
    * File description
    * Legal copyright
    * Original filename
    * Company name
  * Support for file path input or FilePicker selection
  * Cross-platform API design (currently implemented for Windows)

* Platforms:
  * Windows: Full implementation
  * Other platforms: API ready but not implemented yet
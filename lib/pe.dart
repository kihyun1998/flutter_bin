/// The PE *image view*: reads the version resource embedded in a Windows PE
/// binary by parsing the file itself.
///
/// A separate entry point from `package:flutter_bin/flutter_bin.dart` on purpose.
/// The main API asks the OS what it reports for a file — locale dependent, and
/// it follows MUI satellite resources. This one reports what the image carries.
/// The two agree for most binaries; where they differ, the type you hold tells
/// you which view you are looking at.
///
/// Parsing is pure Dart, so it runs on any host (including the Linux CI job) and
/// reads binaries the Win32 version APIs cannot — images whose `RT_VERSION`
/// resource is stored under a name string rather than the numeric id `1`.
library;

export 'models/binary_file_metadata.dart';
export 'models/pe_version_resource.dart';
export 'src/windows/pe_version_reader.dart'
    show
        readPeVersionResource,
        readPeVersionResources,
        parsePeVersionResource,
        parsePeVersionResources,
        selectPeVersionResource;

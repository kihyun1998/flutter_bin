# flutter_bin_example

Demonstrates how to use the flutter_bin package.

Pick a binary with **Select Binary File**, then:

- **Get Version** / **Get Full Metadata** — the OS view, via
  `getBinaryFileVersion` / `getBinaryFileMetadata`.
- **Read PE Image View** — the image view, via `readPeVersionResources`. Lists
  every version resource the file carries with every key and value, marks the leaf
  the singular `readPeVersionResource` selects, and shows what
  `toBinaryFileMetadata()` maps it to. The first rows put `originalFilename` from
  both views side by side, which is where they disagree — see the package README's
  "Two Views of a Windows Binary".

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

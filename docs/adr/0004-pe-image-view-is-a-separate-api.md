# The PE image view is a separate API, never a fallback

Status: accepted

Some PE binaries store their `RT_VERSION` resource under a **name string** rather
than the numeric id `1` — `windres` emits this, and FileZilla 3.66.5 is a shipped,
signed example. The Win32 version APIs look up the numeric id only, so
`GetFileVersionInfoSizeW` returns 0 (`ERROR_RESOURCE_TYPE_NOT_FOUND`) and every
consumer of them — Explorer, PowerShell, and `getBinaryFileMetadata` — reports the
file as carrying no version info, while the resource sits intact in the image.

Parsing the PE ourselves recovers those files. The question this ADR settles is
where that capability lives, because the parser does **not** answer the same
question `version.dll` does:

- `version.dll` answers "what does the OS report for this file?" — it follows MUI
  satellite resources and is locale dependent. `C:\Windows\System32\mstsc.exe`
  reports `originalFilename` as `mstsc.exe.mui`.
- Parsing the image answers "what is embedded in this file?" — locale independent,
  no satellites. The same binary reports `mstsc.exe`.

Both are correct for their own question. So we ship the image view as an additive,
explicitly-named API (`package:flutter_bin/pe.dart`, `readPeVersionResource`,
`PeVersionResource`) and leave `getBinaryFileVersion` / `getBinaryFileMetadata`
untouched. Choosing which view is acceptable is caller policy.

The singular entry points return the leaf **id `1`** when the image has one, else
the first the directory lists — see *Consequences*.

## Considered Options

- **Replace the FFI reader with the PE parser.** Rejected: it silently changes
  `originalFilename` for MUI-based system binaries (`mstsc.exe.mui` becomes
  `mstsc.exe`), a breaking change for callers matching on that field, with no way
  for them to detect it.
- **Fall back to the parser inside the existing methods when the OS reads
  nothing.** Rejected: one method would then return the OS view for most files and
  the image view for others, with no way for the caller to tell which it got. No
  value is overwritten by such a fallback, but the *meaning* of the return value
  stops being fixed.
- **Extend `BinaryFileMetadata` with the extra fields.** Rejected: the model is
  cross-platform, and `stringTables` / `resourceName` / `languageId` have no
  macOS equivalent — they would be permanently empty there, next to the existing
  always-empty `companyName`. Worse, an empty `stringTables` would no longer
  distinguish "macOS", "read through the OS view", and "PE with no tables".
- **A separate entry point and a separate type (chosen).** The type a caller holds
  states which view produced it, so provenance survives without a runtime flag.

## Consequences

- The two views can disagree in three ways: MUI redirection, locale, and — because
  resource directories sort *named* entries before numeric ids — **which entry** is
  selected. The third is why the singular API prefers id `1`: without the rule, an
  image carrying both `#1` and `VS_VERSION_INFO` would report the named entry here
  and the `#1` entry through the OS view, so the views would describe different
  resources. `readPeVersionResources` exposes every leaf when that matters, and
  `selectPeVersionResource` exposes the rule.
- `PeVersionResource.fixedFileVersion` carries all four components, which is the
  "separate, explicitly-named field" ADR-0003 anticipated; `toBinaryFileMetadata()`
  applies the ADR-0003 semver truncation so existing validation code still sees a
  3-part `version`.
- The parser is pure Dart, so it runs on any host and its tests execute on the
  Linux CI job. It reads only the headers and the resource section, not the file.
- Consequence of that windowing: the file-based reader cannot follow a version
  payload that lives in a section other than the one holding the resource
  directory (the in-memory `parsePeVersionResource` still can). No known PE
  toolchain emits that layout.

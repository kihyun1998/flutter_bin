# Dart enum is the canonical source for method-channel metadata keys

Status: accepted

The metadata key strings (`version`, `productName`, …) are used in three places —
the Dart `BinaryFileMetadataJsonKey` enum, the Swift dictionary literals, and the
Windows C++ `metadata[...]` assignments — with no compiler-enforced link between
them, so a rename could silently desync the platforms. We designate the Dart enum
`BinaryFileMetadataJsonKey` as the single source of truth, document the contract in
`docs/method-channel-contract.md`, and add per-platform tests that fail if a side
drifts from the key set.

## Considered Options

- **Code-generate the keys for all three languages from one source.** Rejected as
  overkill for six stable keys; it adds a build step and toolchain dependency far
  heavier than the problem.
- **A standalone `docs` file as the source of truth.** Rejected as the *primary*
  source: nothing executes a doc, so it drifts silently. The doc still exists, but
  it points at the enum rather than being authoritative itself.
- **Dart enum as source, guarded by tests (chosen).** The enum already exists and
  is used by `BinaryFileMetadata.fromJson`; the native sides mirror it and tests
  catch drift on each platform.

## Consequences

- Native code still hardcodes the key strings (it cannot import Dart); the safety
  net is the test on each platform, not the type system.
- Adding/renaming a key is a deliberate three-file change plus the canonical list
  in the Dart test — by design, so the contract change is explicit.

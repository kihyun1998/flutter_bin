# Version string is a semantic version across platforms

Status: accepted

`getBinaryFileVersion` (and the `version` metadata field) previously returned a
platform-divergent shape: Windows produced the 4-part PE file version
(`major.minor.build.revision`, e.g. `6.2.26100.8521`) while macOS returned the
3-part `CFBundleShortVersionString` (e.g. `3.1.4`). Callers had to special-case the
platform. We unify on semantic versioning (`major.minor.patch`): Windows now drops
the trailing revision component, and macOS is unchanged (already a short/semantic
version by convention).

## Considered Options

- **Standardize on the 4-part Windows shape.** Rejected: macOS has no natural 4th
  component, and `major.minor.patch` is the widely understood version format.
- **Leave the difference and document it as intentional.** Rejected: it pushes
  per-platform branching onto every caller for no benefit.
- **Semver, Windows drops the revision (chosen).** One predictable shape everywhere.

## Consequences

- **Breaking change** for existing Windows callers: the build/revision detail is no
  longer exposed (e.g. `6.2.26100.8521` becomes `6.2.26100`). If the full 4-part
  file version is ever needed, it should be a separate, explicitly-named field.
- The Windows characterization test now asserts a 3-part semver shape.

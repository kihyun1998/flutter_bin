# Version is returned as the source states it

Status: accepted. Supersedes [ADR-0003](0003-version-string-is-semver.md).

Every reader returns `version` exactly as its source states it:

- Windows, both the OS view and the PE image view: all four parts of the
  `VS_FIXEDFILEINFO` file version, `major.minor.build.revision`
  (e.g. `10.0.26100.9711`).
- macOS: `CFBundleShortVersionString`, unchanged.

This is a maintainer judgement (2026-10-26, #37), not a derivation: the
maintainer judged ADR-0003 a wrong decision.

## Context

ADR-0003 made every `version` three parts. It truncated Windows to match macOS,
on the assumption that `CFBundleShortVersionString` is already three parts by
Apple convention. The assumption is false. The macOS reader never checked it,
and real values come back as written: against temporary bundles on 2026-10-26,
`1.2.3.4`, `2.0` and `1.2.3-beta` were each returned as-is.

So the three-part shape held on Windows only, and only because the revision was
discarded. The revision is real data. On 2026-10-26 the OS view reported
`10.0.26100` for `kernel32.dll`, whose file version is `10.0.26100.9711`, and
`10.0.26100` for `notepad.exe`, whose file version is `10.0.26100.9278`.

## Considered Options

- **Keep truncating Windows.** Rejected: it loses the revision to match a shape
  macOS does not deliver.
- **Normalise macOS to three parts as well.** Rejected:
  `CFBundleShortVersionString` is free text. Truncating, padding or stripping a
  suffix changes what the bundle says (`1.2.3-beta` would lose `-beta`), and the
  rule for each irregular case would be invented here.
- **Keep three parts in `version` and add a four-part field.** Rejected: the
  default field would stay the lossy one.
- **Return the source's own value (chosen).**

## Consequences

- **Breaking change** for Windows callers, in 4.0.0: `6.2.26100` becomes
  `6.2.26100.8521`. `PeVersionResource.toBinaryFileMetadata().version` now
  equals `fixedFileVersion`.
- `version` no longer has one shape across platforms. A caller that compares
  versions parses the string itself.
- `formatFullVersion` is the only fixed-version formatter; the three-part
  `formatFixedVersion` is removed.
- What it was decided on: the macOS reproduction and the Windows measurements
  above. It does not cover which Windows source `version` is read from (the
  numeric fixed info or the `FileVersion` string, #49), or how absence is
  reported (#48).

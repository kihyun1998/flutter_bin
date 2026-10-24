# CLAUDE.md

## Agent skills

### Issue tracker

Issues and specs live as GitHub issues in `kihyun1998/flutter_bin`, managed via the `gh` CLI. External PRs are not a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Comments

A comment says what the code is. Why it is this way, what it deliberately leaves out, the trap and the measured value go to the territory note under `docs/map/`. Where none seems to hold it, search the folder and the code symbol first; only then start a new note, named for what the system does there, not for the file. History goes to the commit message. Comments written before this rule still carry the rest: never delete one whose content the map does not yet hold — move it first (`decant`).

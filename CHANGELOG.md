# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). No release has passed the
full gate in `docs/ACCEPTANCE.md`, so nothing here is tagged `vX.Y.Z`.

## [Unreleased]

### Added
- `.gitattributes` (line-ending normalization), tracked `.githooks/pre-commit`,
  `.harness-checks.example.json`, GitHub Actions CI (not yet run on GitHub),
  `CONTRIBUTING.md`, this changelog, decisions D-005 and D-006 (both Proposed).
- README quick start, checks and development sections.

### Removed
- Self-correction loop from `6ef6879`, reverted in `1982d09` (unreachable, dead
  apply step, missing checkpoint/rollback functions, bypassed D-003).

## History before this file
- `9c27aad` Establish verified project baseline
- `fa0b9a4` Add manage_repo.ps1 and repair_harness.py utilities
- `2192e3a` docs: update and standardize README.md specifications
- `6ef6879` feat: add automated self-correction verification feedback loop (reverted)

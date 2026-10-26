# Acceptance Criteria — 90-Day Engineering Harness Objective

## Current Status

All baseline measurements are **unknown until verified in the current repository and environment**. Written criteria are targets, not evidence of achievement.

## Release Gate

The release gate passes only when every applicable criterion below has been verified.

1. `python -m py_compile src/harness.py` exits with code `0`.
2. `python -m pytest -q` exits with code `0` on a clean checkout.
3. Path-safety tests reject path traversal, absolute paths, symlinks, and files outside the permitted allowlist, where applicable.
4. Invalid model JSON and schema mismatches fail closed with actionable errors.
5. Patch application validates target paths and runs `git apply --check` before modifying files.
6. Verification runs only project-owner-configured commands and does not invoke a shell.
7. Each run records its status, timestamp, model/provider where applicable, relevant Git state, and failure details in the JSONL ledger.
8. Evaluation distinguishes valid output structure from semantic correctness.
9. Setup and tests can be reproduced from the README instructions in a clean checkout.

**Evidence rule:** Record the command or test performed, its actual result, and any limitations. Do not mark a criterion as passed based solely on documentation, code inspection, or a successful process exit when the relevant behavior was not tested.

## Day-30 Gate

- At least 10 deterministic regression tests pass.
- No known critical safety regression remains unresolved.
- Failure reports preserve actionable provider/API error details.
- A tagged baseline commit exists and can be reproduced.

## Day-60 Gate

- At least 20 representative task cases have been recorded.
- Correctness is graded against human-reviewed expected outcomes.
- Manual and harness-assisted completion times are measured on comparable tasks.
- Known failure modes and unresolved risks are documented.

## Day-90 Target

- At least 90% of the fixed evaluation suite passes its predefined acceptance criteria.
- At least 5 net hours per week are saved during a representative real-work trial.
- Zero unauthorized writes or external actions occur during evaluation.
- Setup, tests, known limitations, and a rollback procedure are documented and reproducible.

## Stop Conditions

- **Unauthorized write or command execution:** Stop real-project use until the root cause is understood and a regression test is in place.
- **Unresolved blocking failure:** After two focused debugging sessions without a reproducible cause, reduce scope and isolate a minimal reproduction.
- **No measured time savings by day 60:** Narrow the use case or stop feature expansion.
- **Day-90 target not met:** Do not extend automatically. Compare measured value against the next-best use of time.

## Current Verification Record

Update this section only when new evidence is available.

### 2026-10-26, commit b2d6213, fresh `git clone` + new venv
Environment: Linux, Python 3.12.3, `pip install -e ".[test]"`. Windows and Python 3.10 not tested.

- Gate 1 `python -m py_compile src/harness.py`: exit 0 (observed).
- Gate 2 `python -m pytest -q -p no:cacheprovider tests`: exit 0, 32 passed, 0 skipped (observed). The earlier record shows 31 passed, 1 skipped; the difference is likely a platform-dependent skip and was not investigated.
- Gate 9 (partial): README quick-start commands (install, compile, pytest, `python -m harness --help`) ran as written on Linux only.
- Gates 3-8: not independently verified in this pass. Existing tests may cover some; they were not mapped to criteria.
- CI workflow added but not yet executed on GitHub.
- Day-30 gate: baseline tag created locally (see CONTRIBUTING.md); at least 10 regression tests exist (32). "No known critical safety regression" not assessed.
- Day-60 / Day-90 criteria: **not measured.** Real-world time savings: **not measured.**

### Previously reported (unverified here)
- Automated tests: 31 passed, 1 skipped.
- Release gate: **Not yet fully verified.**

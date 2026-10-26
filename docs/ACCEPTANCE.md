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

- Source compilation: previously reported passing; rerun if the source changes.
- Automated tests: previously reported 31 passed, 1 skipped; rerun if the source or tests change.
- Release gate: **Not yet fully verified.**
- Clean-checkout reproducibility: **Not yet verified.**
- Real-world time savings: **Not yet measured.**
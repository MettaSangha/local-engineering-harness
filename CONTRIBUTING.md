# Contributing / Version Control

## Branches
- `main` stays green: `py_compile` and `pytest` pass on every commit.
- Work on short-lived branches: `feat/…`, `fix/…`, `chore/…`, `docs/…`. One purpose each.

## Commits
- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `revert:`).
- Atomic: one logical change per commit; behavior changes ship with their tests.
- Body explains why, and states what was actually run. Do not claim untested results.

## Merging
- Rebase on `main`, then `git merge --ff-only` to keep history linear.
- Never force-push `main`. Never rewrite pushed history.

## Undoing
- Use `git revert <sha>`; history stays intact and the revert is itself revertible.
- Lost something? `git reflog` first. Avoid `git reset --hard` on anything unpushed.

## Tags
- Annotated only. `baseline-YYYY-MM-DD` marks a measured baseline.
- `vX.Y.Z` is reserved for commits where the full release gate in
  `docs/ACCEPTANCE.md` has been verified.

## Hooks and line endings
- `git config core.hooksPath .githooks` (runs `py_compile` + `pytest` before each commit).
- `.gitattributes` keeps the index LF; do not commit CRLF-only churn.

## Evidence rule
Update `docs/ACCEPTANCE.md` only with the command run, its actual result, and its limits.

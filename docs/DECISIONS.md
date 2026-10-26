# Decision log

Record decisions that constrain future work. Append new entries; do not silently rewrite history.

## D-001 — Keep the harness local-first and dependency-light
- **Status:** Accepted
- **Context:** Target machine has 8 GB RAM and limited budget. Local inference should remain usable without paid API access.
- **Decision:** Keep core runtime on the Python standard library; make pytest an optional development dependency. Keep local Ollama as the default provider and support a replaceable remote provider.
- **Trade-off:** More manual validation code, but lower installation friction and fewer runtime dependencies.
- **Revisit when:** Reliability or maintenance evidence shows that a dependency materially reduces total cost.

## D-002 — Read-only by default; explicit approval for patch application
- **Status:** Accepted
- **Context:** Model output and repository content are untrusted and can be wrong or adversarial.
- **Decision:** Analysis does not write project files. Patch application requires explicit interactive approval and `git apply --check` before applying.
- **Trade-off:** Slower than autonomous writes; materially lowers accidental-change risk.
- **Revisit when:** A separately tested sandbox and rollback path exist.

## D-003 — Execute only owner-configured verification commands
- **Status:** Accepted
- **Context:** A model must not choose arbitrary commands to execute.
- **Decision:** Checks are explicit argument arrays in `.harness-checks.json`; subprocess uses `shell=False`.
- **Trade-off:** Project owners must configure checks.
- **Revisit when:** A reviewed, safe project-type registry is implemented and tested.

## D-004 — Treat structured output validity and task correctness as separate metrics
- **Status:** Accepted
- **Context:** Valid JSON does not prove a useful or correct engineering answer.
- **Decision:** Report schema/latency evaluation separately from human-reviewed correctness and net time saved.
- **Trade-off:** More evaluation effort; avoids inflated success claims.
- **Revisit when:** A reliable labeled evaluation set exists.

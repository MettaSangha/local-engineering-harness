# Local Engineering Harness

A local-first Python tool for structured engineering analysis, bounded project context, validated patch proposals, explicit patch approval, configurable verification, and auditable run records.

## Core Features & Mechanics
- **Bounded Context Engine:** Strict allowlist and SHA-256 verification.
- **Structured Analysis & Validation:** JSON Schema validation.
- **Validated Patch Proposals:** Unified diff parsing and hash checks.
- **Explicit Guardrails:** Requires typing APPLY and Git validation.
- **Subprocess Verification:** Configurable via .harness-checks.json with shell=False.
- **Model Providers:** Ollama and OpenRouter support.
- **Auditable Run Ledger:** JSON Lines execution logging.

## System Requirements & Setup
- Python 3.10+, Git 2.25+, pytest, Ollama or OpenRouter.

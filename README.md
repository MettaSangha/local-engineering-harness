# Local Engineering Harness

A local-first Python tool for structured engineering analysis, bounded project context, validated patch proposals, explicit patch approval, configurable verification, and auditable run records.

The goal is to make AI-assisted engineering work **reviewable, measurable, and reproducible**—without treating model output as proof of correctness.

## Current status

**Baseline:** The current working tree has reported 31 passing tests and 1 skipped test. Python compilation has also completed without a reported error.

These are local test results, not an independent security audit. Re-run the checks after cloning the repository or making changes. Features that depend on a model provider require separate integration testing.

## Features

- **Bounded context:** Reads selected files from a fixed source allowlist and records SHA-256 hashes of the supplied text.
- **Structured analysis:** Validates required JSON fields and basic value constraints before displaying an assessment.
- **Patch proposals:** Checks unified-diff structure, restricts target paths, and verifies source hashes before offering application.
- **Explicit approval:** Patch application requires the operator to type `APPLY`; Git checks the diff before applying it.
- **Configurable verification:** Runs argument arrays configured in `.harness-checks.json`, without invoking a shell through Python's subprocess API.
- **Model providers:** Supports local Ollama and OpenRouter through replaceable provider functions.
- **Run ledger:** Writes JSON Lines records under the user's local application-data directory.
- **Evaluation:** Measures response validity and elapsed time; it explicitly does not equate valid JSON with semantic correctness.
- **Verified lessons:** Allows a user to save and retrieve lessons after an explicit confirmation step.

## Safety and limitations

This tool is an engineering aid, **not a security sandbox**.

- Model output and repository files must be treated as untrusted input.
- An allowlist limits which project files the tool reads or targets with its patch workflow; it does not isolate the Python process from the operating system.
- Configured verification commands run with the current user's permissions. Review every command before running it.
- `shell=False` prevents Python from asking a command shell to interpret the argument list; it does not make a dangerous executable or argument safe.
- Patch validation reduces certain malformed-path and stale-source risks. It does not establish that a patch is logically correct or free of every possible risk.
- A successful process exit or valid JSON response does not prove that an engineering task is correct.
- When OpenRouter is selected, supplied task and project context are sent to an external provider. Do not include secrets, credentials, or confidential files in that context.
- The run ledger and verified-lesson store may contain project-related metadata or task text. Review their contents before sharing logs.

Use synthetic data and a disposable Git repository for initial testing. Do not use the harness on critical production files until its behavior and limitations have been reviewed.

## Requirements

- Python 3.10 or newer
- Git
- pytest for running the test suite
- Ollama for local model inference, or an OpenRouter API key for remote inference

The core application uses Python's standard library. pytest is an optional development dependency.

## Setup

Run these commands from the repository root in PowerShell:

```powershell
python --version
git --version
python -m pip install -e ".[test]"
```

If `python` resolves to the wrong interpreter on Windows, use the appropriate Python launcher or interpreter path consistently.

## Quick start

Compile the application:

```powershell
python -m py_compile .\src\harness.py
```

Run the test suite:

```powershell
python -m pytest -q -p no:cache
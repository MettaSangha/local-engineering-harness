
"""Deterministic regression tests for safety-critical harness utilities."""

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import harness  # noqa: E402


class FakeResponse:
    def __init__(self, payload: bytes):
        self.payload = payload
        self.calls = 0

    def read(self, amount=-1):
        self.calls += 1
        if amount < 0:
            amount = len(self.payload)
        result, self.payload = self.payload[:amount], self.payload[amount:]
        return result


def test_bounded_read_reads_once_and_returns_content():
    response = FakeResponse(b"hello")
    assert harness.bounded_read(response, limit=10) == b"hello"
    assert response.calls == 1


def test_bounded_read_rejects_oversized_response():
    response = FakeResponse(b"12345")
    with pytest.raises(harness.HarnessError, match="exceeds"):
        harness.bounded_read(response, limit=4)


@pytest.mark.parametrize(
    "path",
    ["../secret", "src/../../secret", "/etc/passwd"],
)
def test_safe_path_rejects_traversal_and_absolute_paths(tmp_path, path):
    with pytest.raises(harness.HarnessError):
        harness.safe_path(tmp_path, path)


def test_safe_path_rejects_non_allowlisted_file(tmp_path):
    with pytest.raises(harness.HarnessError, match="not allowlisted"):
        harness.safe_path(tmp_path, "secrets.env")


def test_safe_path_rejects_symlink(tmp_path):
    target = tmp_path / "target.txt"
    target.write_text("safe", encoding="utf-8")
    link = tmp_path / "README.md"

    try:
        link.symlink_to(target)
    except (OSError, NotImplementedError):
        pytest.skip("Symlink creation is unavailable in this environment")

    with pytest.raises(harness.HarnessError, match="Symlink"):
        harness.safe_path(tmp_path, "README.md")


def test_validate_assessment_accepts_expected_schema():
    payload = {
        "diagnosis": "A specific diagnosis",
        "proposed_changes": ["Change one"],
        "risks": [],
        "tests": ["Run unit tests"],
        "missing_information": [],
    }
    assert harness.validate_assessment(json.dumps(payload)) == payload


@pytest.mark.parametrize(
    "payload",
    [
        "not json",
        json.dumps({"diagnosis": "x"}),
        json.dumps({
            "diagnosis": "",
            "proposed_changes": [],
            "risks": [],
            "tests": [],
            "missing_information": [],
        }),
        json.dumps({
            "diagnosis": "x",
            "proposed_changes": "not a list",
            "risks": [],
            "tests": [],
            "missing_information": [],
        }),
    ],
)
def test_validate_assessment_rejects_invalid_payloads(payload):
    with pytest.raises(harness.HarnessError):
        harness.validate_assessment(payload)


def test_validate_patch_accepts_empty_diff_for_no_patch_response():
    payload = {
        "summary": "No safe patch can be proposed.",
        "unified_diff": "",
        "risks": ["More information is needed."],
        "tests": [],
    }
    assert harness.validate_patch(json.dumps(payload)) == payload


def test_validate_patch_rejects_blank_risk():
    payload = {
        "summary": "A patch proposal",
        "unified_diff": "",
        "risks": ["   "],
        "tests": [],
    }
    with pytest.raises(harness.HarnessError, match="risks"):
        harness.validate_patch(json.dumps(payload))


def test_validate_patch_rejects_overlong_test_item():
    payload = {
        "summary": "A patch proposal",
        "unified_diff": "",
        "risks": [],
        "tests": ["x" * 1001],
    }
    with pytest.raises(harness.HarnessError, match="tests"):
        harness.validate_patch(json.dumps(payload))


def test_check_patch_paths_accepts_allowlisted_path():
    diff = (
        "--- a/README.md\n"
        "+++ b/README.md\n"
        "@@ -1 +1 @@\n"
        "-old\n"
        "+new\n"
    )
    assert harness.check_patch_paths(diff, harness.ALLOWLIST) == ["README.md"]


@pytest.mark.parametrize(
    "path",
    ["../../outside.txt", "secrets.env", "/tmp/pwned"],
)
def test_check_patch_paths_rejects_unsafe_paths(path):
    diff = (
        f"--- a/{path}\n"
        f"+++ b/{path}\n"
        "@@ -1 +1 @@\n"
        "-old\n"
        "+new\n"
    )
    with pytest.raises(harness.HarnessError):
        harness.check_patch_paths(diff, harness.ALLOWLIST)


def test_check_patch_paths_rejects_file_creation():
    diff = (
        "--- /dev/null\n"
        "+++ b/README.md\n"
        "@@ -0,0 +1 @@\n"
        "+new content\n"
    )
    with pytest.raises(harness.HarnessError, match="not supported"):
        harness.check_patch_paths(diff, harness.ALLOWLIST)


def test_check_patch_paths_rejects_file_deletion():
    diff = (
        "--- a/README.md\n"
        "+++ /dev/null\n"
        "@@ -1 +0,0 @@\n"
        "-old content\n"
    )
    with pytest.raises(harness.HarnessError, match="not supported"):
        harness.check_patch_paths(diff, harness.ALLOWLIST)


def test_verify_patch_sources_accepts_unchanged_file(tmp_path):
    content = b"original content\n"
    (tmp_path / "README.md").write_bytes(content)
    hashes = {"README.md": harness.sha256_bytes(content)}

    harness.verify_patch_sources(
        tmp_path,
        ["README.md"],
        hashes,
    )


def test_verify_patch_sources_rejects_modified_file(tmp_path):
    path = tmp_path / "README.md"
    path.write_bytes(b"original content\n")
    hashes = {"README.md": harness.sha256_bytes(path.read_bytes())}

    path.write_bytes(b"changed content\n")

    with pytest.raises(harness.HarnessError, match="Source changed"):
        harness.verify_patch_sources(
            tmp_path,
            ["README.md"],
            hashes,
        )


def test_verify_patch_sources_rejects_missing_hash(tmp_path):
    (tmp_path / "README.md").write_text(
        "content\n",
        encoding="utf-8",
    )

    with pytest.raises(harness.HarnessError, match="hash"):
        harness.verify_patch_sources(
            tmp_path,
            ["README.md"],
            {},
        )


def test_verify_patch_sources_rejects_missing_file(tmp_path):
    hashes = {"README.md": "0" * 64}

    with pytest.raises(harness.HarnessError, match="missing"):
        harness.verify_patch_sources(
            tmp_path,
            ["README.md"],
            hashes,
        )


def test_verify_patch_sources_rejects_invalid_hash_format(tmp_path):
    (tmp_path / "README.md").write_text(
        "content\n",
        encoding="utf-8",
    )

    with pytest.raises(harness.HarnessError, match="hash"):
        harness.verify_patch_sources(
            tmp_path,
            ["README.md"],
            {"README.md": "not-a-sha256"},
        )


def test_verify_patch_sources_rejects_non_allowlisted_path(tmp_path):
    with pytest.raises(harness.HarnessError, match="allowlisted"):
        harness.verify_patch_sources(
            tmp_path,
            ["secrets.env"],
            {"secrets.env": "0" * 64},
        )


def test_load_checks_rejects_shell_string_instead_of_argument_array(tmp_path):
    (tmp_path / ".harness-checks.json").write_text(
        json.dumps({"checks": ["python -m pytest"]}),
        encoding="utf-8",
    )
    with pytest.raises(harness.HarnessError, match="command arguments"):
        harness.load_checks(tmp_path)


def test_load_checks_accepts_explicit_argument_array(tmp_path):
    expected = [[sys.executable, "-m", "pytest"]]
    (tmp_path / ".harness-checks.json").write_text(
        json.dumps({"checks": expected}),
        encoding="utf-8",
    )
    assert harness.load_checks(tmp_path) == expected


import subprocess


def _create_temporary_git_repo(root: Path) -> None:
    """Create a real temporary Git repository with a committed README."""
    root.mkdir(parents=True, exist_ok=True)
    (root / "README.md").write_text(
        "old content\n",
        encoding="utf-8",
    )

    commands = [
        ["git", "init"],
        ["git", "config", "user.email", "harness-test@example.com"],
        ["git", "config", "user.name", "Harness Test"],
        ["git", "add", "README.md"],
        ["git", "commit", "-m", "Initial test fixture"],
    ]

    for command in commands:
        subprocess.run(
            command,
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        )


def _make_test_patch(root: Path) -> dict:
    """Build a patch and source hash matching the committed README."""
    original = (root / "README.md").read_bytes()

    return {
        "summary": "Replace the README test content.",
        "unified_diff": (
            "--- a/README.md\n"
            "+++ b/README.md\n"
            "@@ -1 +1 @@\n"
            "-old content\n"
            "+new content\n"
        ),
        "risks": [],
        "tests": ["Verify README.md contains the new content."],
        "source_hashes": {
            "README.md": harness.sha256_bytes(original),
        },
    }


def test_integration_approved_patch_applies_and_verifies(
    tmp_path,
    monkeypatch,
):
    """Apply a reviewed patch, then execute an explicit verification check."""
    root = tmp_path / "repo"
    _create_temporary_git_repo(root)
    patch = _make_test_patch(root)

    monkeypatch.setattr("builtins.input", lambda _: "APPLY")

    harness.apply_approved_patch(root, patch)

    assert (root / "README.md").read_text(
        encoding="utf-8"
    ) == "new content\n"

    # This command checks the actual post-patch file contents.
    check_code = (
        "from pathlib import Path; "
        "assert Path('README.md').read_text(encoding='utf-8') "
        "== 'new content\\n'"
    )
    (root / ".harness-checks.json").write_text(
        json.dumps(
            {
                "checks": [
                    [sys.executable, "-c", check_code],
                ]
            }
        ),
        encoding="utf-8",
    )

    results = harness.run_checks(root, timeout=10)

    assert len(results) == 1
    assert results[0]["status"] == "passed"
    assert results[0]["returncode"] == 0


def test_integration_stale_source_is_rejected_before_application(
    tmp_path,
    monkeypatch,
):
    """A reviewed patch must not apply after its source has changed."""
    root = tmp_path / "repo"
    _create_temporary_git_repo(root)
    patch = _make_test_patch(root)

    # Simulate a change made after the model proposed the patch.
    (root / "README.md").write_text(
        "concurrent change\n",
        encoding="utf-8",
    )
    monkeypatch.setattr("builtins.input", lambda _: "APPLY")

    with pytest.raises(harness.HarnessError, match="Source changed"):
        harness.apply_approved_patch(root, patch)

    # The patch did not overwrite the concurrent change.
    assert (root / "README.md").read_text(
        encoding="utf-8"
    ) == "concurrent change\n"


def test_integration_declined_patch_leaves_file_unchanged(
    tmp_path,
    monkeypatch,
):
    """Declining approval must leave the working file untouched."""
    root = tmp_path / "repo"
    _create_temporary_git_repo(root)
    patch = _make_test_patch(root)

    monkeypatch.setattr("builtins.input", lambda _: "NO")

    harness.apply_approved_patch(root, patch)

    assert (root / "README.md").read_text(
        encoding="utf-8"
    ) == "old content\n"

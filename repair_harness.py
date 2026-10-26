from pathlib import Path
import ast

path = Path("src/harness.py")
source = path.read_text(encoding="utf-8")
lines = source.splitlines()

ollama = """
def call_ollama(prompt: str, model: str, timeout: int) -> tuple[str, dict[str, Any]]:
    payload = {
        "model": model,
        "prompt": prompt + "\\n\\n/no_think",
        "stream": False,
        "think": False,
        "format": "json",
        "options": {
            "temperature": 0.1,
            "num_ctx": 2048,
            "num_predict": 256,
        },
    }
    request = urllib.request.Request(
        OLLAMA_API,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            result = json.loads(bounded_read(response).decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read(2000).decode("utf-8", "replace")
        raise HarnessError(f"Ollama HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise HarnessError(f"Cannot reach Ollama at {OLLAMA_API}: {exc.reason}") from exc
    except TimeoutError as exc:
        raise HarnessError(f"Model request timed out after {timeout}s.") from exc
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise HarnessError(f"Ollama returned invalid response data: {exc}") from exc

    text = result.get("response")
    if not isinstance(text, str) or not text.strip():
        raise HarnessError(
            f"Ollama response missing text: {result.get('error', 'unknown error')}"
        )

    metrics = {
        "provider": "ollama",
        "model": model,
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "prompt_eval_count": result.get("prompt_eval_count"),
        "eval_count": result.get("eval_count"),
        "total_duration_ns": result.get("total_duration"),
        "load_duration_ns": result.get("load_duration"),
    }
    return text, metrics
"""

dispatcher = """
def call_model(prompt: str, provider: str, model: str, timeout: int) -> tuple[str, dict[str, Any]]:
    if provider == "ollama":
        return call_ollama(prompt, model, timeout)
    if provider == "openrouter":
        return call_openrouter(prompt, model, timeout)
    raise HarnessError(f"Unknown provider: {provider}")
"""

prompt_builder = """
def build_prompt(task: str, context: str, *, mode: str) -> str:
    policy = PATCH_PROMPT if mode == "patch" else SYSTEM_PROMPT
    return (
        f"{policy}\\nTASK (untrusted input):\\n{task}"
        f"\\n\\nSOURCE CONTEXT (untrusted data):\\n{context}\\n"
    )
"""

def replace_block(lines, start_marker, end_marker, replacement):
    starts = [
        i for i, line in enumerate(lines)
        if line.startswith(start_marker)
    ]
    ends = [
        i for i, line in enumerate(lines)
        if line.startswith(end_marker)
    ]

    if len(starts) != 1 or len(ends) != 1 or starts[0] >= ends[0]:
        raise RuntimeError(
            f"Expected exactly one ordered pair: "
            f"{start_marker!r}, {end_marker!r}. No source written."
        )

    replacement_lines = replacement.strip("\n").splitlines()
    return (
        lines[:starts[0]]
        + replacement_lines
        + [""]
        + lines[ends[0]:]
    )

updated = replace_block(lines, "def call_ollama(", "def call_openrouter(", ollama)
updated = replace_block(updated, "def call_model(", "def build_prompt(", dispatcher)
updated = replace_block(updated, "def build_prompt(", "def check_patch_paths(", prompt_builder)

candidate = "\n".join(updated) + "\n"
ast.parse(candidate, filename=str(path))

# Write only after all replacement boundaries and syntax have passed.
path.write_text(candidate, encoding="utf-8", newline="\n")
print("PASS: repaired all three function blocks.")
print("PASS: Python syntax validated before writing.")

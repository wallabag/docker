import json
import os
from pathlib import Path
import subprocess
import sys

import pytest


@pytest.fixture
def run_entrypoint(tmp_path):
    def run(env):
        return subprocess.run(
            # Skip only the container-specific working directory, not the entrypoint.
            ["/bin/sh", "-c", 'cd() { :; }; . "$ENTRYPOINT"', "test-entrypoint",
             sys.executable, "-c", "import json, os; print(json.dumps(dict(os.environ)))"],
            env={"PATH": os.defpath,
                 "ENTRYPOINT": str(Path(__file__).resolve().parents[1] / "root/entrypoint.sh"),
                 **env},
            cwd=tmp_path,
            capture_output=True,
            text=True,
            timeout=5,
        )
    return run


def test_no_secret_files(run_entrypoint):
    result = run_entrypoint({"SECRET": "unchanged", "UNRELATED": "text\nBOGUS__FILE=ignored"})
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["SECRET"] == "unchanged"


@pytest.mark.parametrize("value", [
    "", "hello world", "  padded  ", "quotes'\" backslash\\ dollar$ glob* equals=",
    "first\nsecond", "with final newline\n\n", "$(touch injected); `touch injected`",
])
@pytest.mark.parametrize("filename", [
    "secret with spaces='and quotes", "$(touch injected)", "secret with trailing newline\n",
])
def test_secret_contents_are_preserved(tmp_path, run_entrypoint, value, filename):
    secret = tmp_path / filename
    secret.write_text(value)
    result = run_entrypoint({"SECRET__FILE": str(secret), "SECRET": "overridden"})
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["SECRET"] == value.rstrip("\n")
    assert not (tmp_path / "injected").exists()


def test_multiple_secret_files(tmp_path, run_entrypoint):
    first = tmp_path / "first"
    second = tmp_path / "second"
    first.write_text("one")
    second.write_text("two")
    result = run_entrypoint({"FIRST__FILE": str(first), "SECOND__FILE": str(second)})
    assert result.returncode == 0, result.stderr
    env = json.loads(result.stdout)
    assert (env["FIRST"], env["SECOND"]) == ("one", "two")


def test_unreadable_secret_stops_startup(tmp_path, run_entrypoint):
    result = run_entrypoint({"SECRET__FILE": str(tmp_path / "missing"), "SECRET": "fallback"})
    assert result.returncode != 0
    assert not result.stdout


def test_invalid_variable_names_are_not_evaluated(tmp_path, run_entrypoint):
    result = run_entrypoint({"BAD;touch injected;#__FILE": str(tmp_path / "missing")})
    assert result.returncode == 0, result.stderr
    assert not (tmp_path / "injected").exists()

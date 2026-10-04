"""Check the rule that finds the shell scripts `make coverage` measures.

The Makefile discovers SHELL_SCRIPTS rather than listing them, so a new
script is held at 100% coverage without anyone remembering to add it. These
tests run where the coverage container runs them, from a tar of the files git
would commit, with no .git and no git, so they reimplement the same rule in
Python over the tree: a file ending in .sh or .bash, or whose first line is a
shebang running sh, bash or dash, outside tests/.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MAKEFILE = REPO_ROOT / "Makefile"
SONAR_PROPERTIES = REPO_ROOT / "sonar-project.properties"

# The same expression the Makefile hands awk.
SHEBANG = re.compile(
    r"^#![ \t]*([^ \t]*/)?(env[ \t]+(-[^ \t]+[ \t]+)*)?(ba|da)?sh([ \t]|$)"
)
EXTENSION = re.compile(r"\.(sh|bash)$")

# What a checkout holds besides the files git would commit. The coverage
# container never sees these; skipping them keeps a local run honest.
NOT_COMMITTED = {
    ".git",
    ".claude",
    ".ruff_cache",
    ".pytest_cache",
    "__pycache__",
    "coverage",
    "inbox",
}

# The scripts this repository is known to have. Discovery may find more, but
# never fewer.
KNOWN = {
    "pdf-sign",
    "containers/reader/start-reader",
    "containers/reader/inbox-backend",
    "selinux/generate.sh",
}


def is_shell(path: Path) -> bool:
    if EXTENSION.search(path.name):
        return True
    try:
        with path.open("rb") as handle:
            first = handle.readline().decode("utf-8", "replace").rstrip("\r\n")
    except OSError:
        return False
    return bool(SHEBANG.match(first))


def discover(root: Path) -> set[str]:
    found = set()
    for directory, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in NOT_COMMITTED]
        for name in files:
            path = Path(directory, name)
            relative = path.relative_to(root).as_posix()
            if relative.startswith("tests/"):
                continue
            if path.is_file() and is_shell(path):
                found.add(relative)
    return found


def test_shebang_rule():
    for line in [
        "#!/bin/sh",
        "#!/bin/bash",
        "#!/usr/bin/dash",
        "#! /bin/sh -e",
        "#!/usr/bin/env bash",
        "#!/usr/bin/env -S bash -eu",
        "#!/usr/bin/env sh",
    ]:
        assert SHEBANG.match(line), line
    for line in [
        "#!/usr/bin/env python3",
        "#!/bin/zsh",
        "#!/usr/bin/fish",
        "#!/bin/bashful",
        "# not a shebang",
        "",
    ]:
        assert not SHEBANG.match(line), line


def test_discovery_finds_every_known_script():
    found = discover(REPO_ROOT)
    assert KNOWN <= found, f"discovery missed {sorted(KNOWN - found)}"


def test_discovery_leaves_out_the_tests():
    assert (REPO_ROOT / "tests/shell.test.sh").is_file()
    assert not [p for p in discover(REPO_ROOT) if p.startswith("tests/")]


def test_makefile_discovers_rather_than_lists():
    """A hand written list must not creep back in."""
    text = MAKEFILE.read_text()
    assignments = re.findall(r"^SHELL_SCRIPTS\s*:?=.*$", text, re.MULTILINE)
    assert len(assignments) == 1, assignments
    rule = assignments[0]
    for piece in [
        "git ls-files -z --cached --others --exclude-standard",
        r"/\.(sh|bash)$$/",
        "(ba|da)?sh",
        "grep -v '^tests/'",
        "$(filter-out $(SHELL_EXCLUDE)",
        "$(SHELL_EXTRA)",
    ]:
        assert piece in rule, f"the SHELL_SCRIPTS rule no longer has {piece!r}"


def test_sonar_reads_every_extensionless_script_as_shell():
    """Sonar picks a language by extension only, so each script without one
    has to be named in sonar.lang.patterns.shell to be analyzed at all."""
    match = re.search(
        r"^sonar\.lang\.patterns\.shell=(.*)$",
        SONAR_PROPERTIES.read_text(),
        re.MULTILINE,
    )
    assert match
    patterns = set(match.group(1).split(","))
    missing = sorted(
        p for p in discover(REPO_ROOT) if not EXTENSION.search(p) and p not in patterns
    )
    assert not missing, f"add {missing} to sonar.lang.patterns.shell"

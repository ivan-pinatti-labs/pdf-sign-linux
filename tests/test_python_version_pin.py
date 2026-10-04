"""Keep every copy of "the Python this repository targets" on one version.

The same fact is written down in several places, and nothing derives one from
another:

- `python-version` in .github/workflows/pull-request.yml, the interpreter CI
  sets up for the hooks;
- `sonar.python.version` in sonar-project.properties, which SonarQube Cloud's
  version dependent rules judge the Python against;
- `target-version` in ruff.toml, the Python ruff lints and formats for;
- every `python:3.X-...` image the Makefile pins, which `make coverage` (and
  so sonarqube.yml and the `coverage` pre-push hook) runs the tests in;
- `--python-version` in the header of tests/requirements.txt, the interpreter
  the test lock is resolved for.

Renovate moves none of these tags. .github/renovate.json5 disables the
`uses-with` depType on purpose, and the Makefile images move by digest only,
so every Python bump is a hand edit of all of them at once, which is exactly
the kind of pairing a person forgets. This test is the reminder.
"""

from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = REPO_ROOT / ".github/workflows/pull-request.yml"
SONAR_PROPERTIES = REPO_ROOT / "sonar-project.properties"
MAKEFILE = REPO_ROOT / "Makefile"
LOCK = REPO_ROOT / "tests/requirements.txt"
RUFF = REPO_ROOT / "ruff.toml"

# `python-version: "3.14"`, quoted, as actions/setup-python is given it. The
# quotes are not optional: YAML reads a bare 3.10 as the float 3.1, so an
# unquoted value is a bug worth failing on rather than a spelling to accept.
WORKFLOW_PYTHON = re.compile(
    r'^\s*python-version:\s*"(?P<major>\d+)\.(?P<minor>\d+)"\s*$', re.MULTILINE
)
SONAR_PYTHON = re.compile(
    r"^sonar\.python\.version=(?P<major>\d+)\.(?P<minor>\d+)\s*$", re.MULTILINE
)
# Any python image reference, whatever variable holds it.
MAKEFILE_PYTHON = re.compile(r"/python:(?P<major>\d+)\.(?P<minor>\d+)-[\w.-]*")
RUFF_PYTHON = re.compile(
    r'^target-version\s*=\s*"py(?P<major>\d)(?P<minor>\d+)"\s*$', re.MULTILINE
)
LOCK_PYTHON = re.compile(r"--python-version=(?P<major>\d+)\.(?P<minor>\d+)\b")

AGREE = "They have to move together; nothing derives one from the other."


def ci_python() -> tuple[str, str]:
    matches = WORKFLOW_PYTHON.findall(WORKFLOW.read_text())
    assert len(matches) == 1, (
        f"expected exactly one quoted python-version in {WORKFLOW.name}, "
        f"found {len(matches)}: {matches}"
    )
    return matches[0]


def test_workflow_declares_exactly_one_python_version():
    """More than one would make "the interpreter CI uses" ambiguous."""
    ci_python()


def test_sonar_python_version_matches_ci():
    ci = ci_python()
    sonar = SONAR_PYTHON.findall(SONAR_PROPERTIES.read_text())
    assert sonar == [ci], (
        f"{SONAR_PROPERTIES.name} sets sonar.python.version to {sonar} but "
        f"{WORKFLOW.name} runs Python {'.'.join(ci)}. {AGREE}"
    )


def test_ruff_target_version_matches_ci():
    ci = ci_python()
    ruff = RUFF_PYTHON.findall(RUFF.read_text())
    assert ruff == [ci], (
        f"{RUFF.name} sets target-version to {ruff} but "
        f"{WORKFLOW.name} runs Python {'.'.join(ci)}. {AGREE}"
    )


def test_every_makefile_python_image_matches_ci():
    ci = ci_python()
    images = MAKEFILE_PYTHON.findall(MAKEFILE.read_text())
    assert images, f"no python:3.X image found in {MAKEFILE.name}"
    for image in images:
        assert image == ci, (
            f"{MAKEFILE.name} pins a Python {'.'.join(image)} image but "
            f"{WORKFLOW.name} runs Python {'.'.join(ci)}. {AGREE}"
        )


def test_test_lock_is_compiled_for_ci_python():
    ci = ci_python()
    locked = LOCK_PYTHON.findall(LOCK.read_text())
    assert locked == [ci], (
        f"{LOCK.name} is compiled with --python-version {locked} but "
        f"{WORKFLOW.name} runs Python {'.'.join(ci)}. {AGREE}"
    )

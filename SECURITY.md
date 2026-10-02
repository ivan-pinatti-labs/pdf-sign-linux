# Security Policy

## Supported Versions

Only the latest commit on `main` is supported.

Adobe Reader XI, which the image runs, is end of life and has known
vulnerabilities that nobody can patch. This project's answer is containment:
no network, no capabilities, SELinux confinement, and access to nothing but
the inbox and its own state folders. Report weaknesses in that containment
(a way out of the container, to the network, or to the host's screen,
clipboard or files) as vulnerabilities here. Vulnerabilities in Reader itself
are out of scope.

## Reporting a Vulnerability

Please do not open a public issue for a security vulnerability. Instead,
use GitHub's private
[report a vulnerability](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability)
feature on this repository, if enabled, or contact the maintainer listed in
[.github/CODEOWNERS](.github/CODEOWNERS) through their GitHub profile.

Please include as much detail as possible: steps to reproduce, affected
versions, and the potential impact. Expect an initial response within a
reasonable time, though as an individually maintained project there is no
guaranteed response window.

## What scans what

| Code | Scanned by | Where |
| --- | --- | --- |
| Shell: `pdf-sign`, `selinux/generate.sh`, `start-reader`, `inbox-backend` and the shell tests | shellcheck, shfmt, shebang checks | `checklist-dev-shell`, every commit |
| Python (`selinux/generate.py`, `scripts/`, `tests/`) | ruff, check-ast, debug-statements | `checklist-dev-python`, every commit |
| `containers/reader/Containerfile` | hadolint | `checklist-dev-docker`, every commit |
| `Makefile` | checkmake | `checklist-dev-make`, every commit |
| `.github/workflows/*` | actionlint, zizmor | `checklist-github-actions`, every commit |
| Everything | detect-secrets | `checklist-security-credentials`, every commit |
| Everything SonarQube Cloud has an analyzer for: shell, Python, the Containerfile, YAML, `.github/workflows/*`, secrets | SonarQube Cloud, Sonar way quality gate, plus 100% coverage of the Python and the shell | `sonarqube.yml`, every pull request from a branch of this repository and every push to `main` |

Two layers, deliberately. The pre-commit hooks fail before anything is
pushed; SonarQube Cloud reads the whole repository at once on every pull
request from a branch of this repository (a fork's pull request cannot
receive its token, so a maintainer pushes the branch here first). Neither
replaces the other: SonarQube's shell rules are few and different from
shellcheck's, not a superset of them.

SonarQube Cloud replaced CodeQL here. `codeql.yml` only ever analyzed the
GitHub Actions workflows, since CodeQL cannot read shell or a Containerfile
at all, and the workflows are now covered by SonarQube Cloud next to
actionlint and zizmor. CodeQL's old alerts in the Security tab stop
updating; they are history, not current findings.

The quality gate is the Free plan's built in "Sonar way", which cannot be
edited. It fails on any new issue in new code, so editing a line that
carries an old finding makes that finding count against the pull request.
Fix what a rule asks for, or mark the single finding false positive or
accepted in SonarQube Cloud with the reason; no `# NOSONAR` comments.

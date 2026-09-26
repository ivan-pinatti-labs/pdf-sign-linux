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

# Contributing

Thanks for considering a contribution.

## Before you start

- Search open issues and pull requests first, so effort is not duplicated.
- For a change of any size, open an issue describing what you want to do
  before writing code, so the approach can be discussed up front.

## Never commit documents

Test with your own documents in `inbox/`, which git ignores apart from its
README. Never commit a PDF: personal and business forms are private, and
government forms are copyrighted. Never publish a built image either; see
the Legal section of [README.md](README.md).

## Making a change

1. Fork the repository and create a branch off `main`.
2. Install pre-commit and the hooks this repo wires up:

   ```shell
   pip install pre-commit
   pre-commit install
   ```

   Or work in a devcontainer-airlock workbench, where the hooks run in an
   L2 container that already carries pre-commit and every tool they need;
   see [.devcontainer/README.md](.devcontainer/README.md).

3. Make your change, and run the checks locally before opening a pull
   request:

   ```shell
   pre-commit run --all-files
   ```

   In a workbench, `l2-pre-commit run --all-files` instead: the workbench
   has no `pre-commit` of its own, and this runs the hooks in L2.

   Then the tests, which must keep every script at 100% coverage:

   ```shell
   make coverage
   ```

   It runs the Python tests under coverage.py (Python 3.12, lines and
   branches) and the shell tests under kcov (lines), each in a podman
   container, and fails unless both reach 100%. It needs podman on `PATH`.
   The shell tests stub podman, Wine, CUPS and Ghostscript, so they need
   neither the Reader image nor a desktop. It also runs as a pre-push hook,
   so run `pre-commit install` again in an existing clone to pick up the
   pre-push stage. In a workbench, run it as
   `l2 --engine --net -- make coverage`. A new or changed script ships with
   tests that reach every line of it.

   Changes to the image or launcher also need a manual run, since Reader is
   a GUI program: `make build`, then `make open FILE=...` on a Wayland
   desktop, filling in, printing and signing a document. With SELinux
   enforcing, install the policy module first (`make selinux`), and after a
   `container-selinux` or `selinux-policy` update regenerate it with
   `selinux/generate.sh`.

4. Commit using [Conventional Commits](https://www.conventionalcommits.org/),
   for example `fix: correct a typo in the README`. No ticket prefix is
   required by default.
5. Open a pull request against `main` using the template in
   [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md). Open
   it as a draft first if the checks take a while to run, and mark it ready
   once they are green.

## Updating the test dependencies

`tests/requirements.in` carries the exact pins, and `tests/requirements.txt`
is a lock compiled from it with every hash, which
`pip install --require-hashes` checks. Renovate bumps both. To change one by
hand, edit the `.in` file and regenerate the lock in a container, from the
`tests` directory:

```shell
podman run --rm -v "$PWD:/w:rw,Z" -w /w ghcr.io/astral-sh/uv:python3.12-trixie-slim \
  uv pip compile --generate-hashes --python-version=3.12 --exclude-newer=P7D \
  --output-file=requirements.txt requirements.in
```

That is the command in the lock's own header, which Renovate replays.
`--exclude-newer=P7D` leaves out anything released in the last seven days,
dependencies of dependencies included.

### A security fix younger than seven days

The seven day window also holds back a security release, and Renovate
cannot make an exception: it replays the header's command as written, so its
pull request for a vulnerability alert fails to regenerate the lock and says
so. Update that one package by hand, letting it past the window, in the same
container and from the lock's directory:

```bash
uv pip compile --generate-hashes --python-version=3.12 --exclude-newer=P7D \
  --exclude-newer-package "<package>=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --output-file=requirements.txt requirements.in
```

Then edit the lock's header back to the standard command above, by hand.
Left in, the per package date is fixed, so it would hold that package at
today's releases for good. The lock itself does not change, and the next
Renovate update replays the standard command once the fix is past the window.

## License

By contributing, you agree that your contributions will be licensed under
this repository's [Apache License 2.0](LICENSE.md).

## Code of Conduct

Participation in this project is governed by
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Security issues

Do not open a public issue for a security vulnerability. See
[SECURITY.md](SECURITY.md) instead.

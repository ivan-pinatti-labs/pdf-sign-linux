# pdf-sign-linux agent instructions

Instructions for AI coding agents working in this repository. Claude Code
reads them through `CLAUDE.md`; Codex and CodeRabbit read this file
directly.

## Organization conventions

Shared by every `ivan-pinatti-labs` repository and kept identical across
them, so change it everywhere at once. Where this repository's own sections
are more specific, follow them.

### Everything here is public

- Nothing sensitive, controversial or borderline goes into a commit, pull
  request, issue, comment or committed agent file. That includes secrets,
  tokens, personal paths, email addresses other than a GitHub noreply one,
  host names, LAN addresses and details of anyone's own deployment.
- Personal or machine specific material stays in gitignored files:
  `CLAUDE.local.md` for notes, `.claude/settings.local.json` for settings,
  `.claude/agents/local/` for agents.
- Sensitive content found already committed is reported to a maintainer.
  Never rewrite history or force push to remove it.

### Run binaries in containers, not on the host

A binary that did not come from the operating system's package manager (a
release download, an installer script, a new version under evaluation, a
scanner, a debugging tool) runs inside a rootless Podman container, never
directly on the host. That holds when validating,
testing, checking a new version and debugging.

It holds one level further in as well. In a
[devcontainer-airlock](https://github.com/ivan-pinatti-labs/devcontainer-airlock)
workbench, where the coding agents and their logins live, project code does
not run in the workbench itself: hooks, tests, package installs and
unreviewed binaries run through `l2`, in an L2 container that gets the
working tree and nothing else (no network, no credentials). `l2 --net` adds
network through the workspace's egress proxy, and `l2 --engine` gives a run
the L2 engine, for tests that build or start containers of their own.

```bash
podman run --rm --network=none \
  -v "<only what it needs>:/work:ro,Z" -w /work \
  <image> <binary> [args]
```

- The container gets what the process needs and nothing else. Mount only the
  specific files and folders required, read only. Add network access or
  `:rw` only when the task requires it, and say so.
- Prefer the tool's official image, pinned to a version. For a bare release
  binary use `debian:13-slim` rather than Alpine: glibc builds fail on musl
  with a misleading "No such file or directory".
- On SELinux hosts a bind mount needs a label (`Z`). Do not relabel a large
  tree that other containers also use; copy what is needed into a scratch
  directory and mount that.
- Podman is the default container runtime: rootless, with no daemon.
- Exceptions: the hook environments pre-commit builds, and the containers
  this repository's own `Makefile` or hooks start. In a workbench both run in
  L2 too.

### Parallel work uses worktrees

More than one agent may work in a repository at the same time. Give each task
its own worktree under `.claude/worktrees/<branch>` (gitignored), and never
switch branches in a checkout someone else may be using.

### Unattended work runs on a bounded tick

Work left running while nobody is watching is driven by a bounded pass, never
by a wait for the outcome you want.

A background wait whose only exit is success does not fail, it disappears. A
pull request sitting in a merge queue is the worked example: a flaky check
ejects it, which is neither merged nor closed, so a loop waiting for "merged"
runs forever, nothing notifies, and the session stops. That cost roughly
sixteen unattended hours here on 2026-09-22, and the giveaway is that silence
and progress look identical from outside.

So:

- **Cap every pass**, around fifty minutes, and report on exit whether or not
  anything moved. Time always advances, so no condition can trap it. Say
  plainly when a pass did nothing, because a quiet pass and a dead session
  have to look different.
- **Re-derive state from the API every pass.** Draft status, review verdict,
  unresolved threads, approval, queue membership. Never carry a belief from
  the previous pass.
- **Handle every outcome, not only the good one.** Released from draft,
  review declined, approval job timed out, ejected from the queue, merged,
  closed. Only the last two are final; the rest are recoverable, and that is
  exactly why they have to be handled rather than waited through. A pass that
  only knows how to recognize success cannot recover anything, and treating a
  recoverable outcome as an ending is the failure this whole section is about.
- **Before arming a wait, ask what would wake you if this failed right now.**
  If the answer is nothing, widen the condition.
- **A pass that ends with nothing moved and no reason is a signal to
  inspect**, not to re-arm the same watch.
- **Never finish a turn** without either a bounded wait armed or an explicit
  statement that work has stopped.

### Writing style

Do not use a hyphen, em dash or en dash as punctuation in prose, code
comments, commit messages or pull request text. Use commas, parentheses or
separate sentences. Hyphens inside compound words and in code, paths, flags
and identifiers are fine.

### Commits and pull requests

- Conventional Commits with an imperative subject. Branch names are lowercase
  slugs such as `fix/flaky-test`. Never commit directly to `main`.
- Open a pull request as a draft and mark it ready once the checks are green;
  marking it ready is what starts CodeRabbit. `docs/MERGE_PIPELINE.md` is the
  authority on required checks and how a pull request merges.
- Answer every CodeRabbit comment on its thread, and say plainly when
  declining one and why.
- Never force push.
- Never add AI attribution: no AI `Co-Authored-By` trailer and no "Generated
  with" line, in commits, pull requests, comments, issues or docs.

## What this repository is

pdf-sign-linux fills in and signs PDF documents with Adobe Reader XI (the
Windows version) under Wine, in a rootless podman container. It exists for
dynamic XFA forms, which nothing else on Linux renders. See `README.md` for
usage and the isolation model.

- `pdf-sign` is the launcher (`build`, `open`); the `Makefile` wraps it.
  `containers/reader/` holds the image: `Containerfile`, the entrypoint
  `start-reader`, the CUPS backend `inbox-backend` with `inbox.ppd`, and the
  registry defaults `reader.reg`.
- `inbox/` is where documents go in and out. Only its `README.md` is
  committed. Never commit a PDF or any other document, and never read,
  copy or quote a user's documents beyond what a task needs.
- Never publish a built image (GHCR, Docker Hub or anywhere else): it
  contains Adobe Reader and Microsoft's fonts, whose licences do not allow
  redistribution. The repository must never contain their files either;
  the build downloads them on the user's machine.
- The container stays locked down: `--network=none`, `--cap-drop=ALL`, only
  the inbox and state folders mounted, only the Wayland socket from the
  desktop (no X11, D-Bus, PipeWire or portals), `WAYLAND_DISPLAY` hidden
  from everything but the private Xwayland, and SELinux enforcing through
  `pdf_sign_t`. A change that loosens any of these needs a stated reason.
- `selinux/pdf_sign.cil` is generated by `selinux/generate.sh`: edit
  `generate.py` and regenerate rather than editing the `.cil`. Installing
  it needs sudo, so ask the user to run `make selinux`. Denials for
  `pdf_sign_t` are readable without root with
  `journalctl _TRANSPORT=audit | grep pdf_sign`.
- Reader is a GUI program, so an end to end check means `make open` on a
  Wayland desktop. Say so when a change was verified only by building.
- The image is about 2.6 GB and building it installs Reader under Wine,
  which takes several minutes. `COPY` the small scripts after the install
  stage so editing them does not reinstall Reader.

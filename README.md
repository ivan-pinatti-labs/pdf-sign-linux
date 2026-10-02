# pdf-sign-linux

[![License](https://img.shields.io/github/license/ivan-pinatti-labs/pdf-sign-linux?logo=Github&style=for-the-badge)](LICENSE.md)
[![GitHub issues](https://img.shields.io/github/issues-raw/ivan-pinatti-labs/pdf-sign-linux?logo=Github&style=for-the-badge)](https://github.com/ivan-pinatti-labs/pdf-sign-linux/issues)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/ivan-pinatti?logo=Github&style=for-the-badge)](https://github.com/sponsors/ivan-pinatti)
[![GitHub Repo stars](https://img.shields.io/github/stars/ivan-pinatti-labs/pdf-sign-linux?logo=Github&style=for-the-badge)](https://github.com/ivan-pinatti-labs/pdf-sign-linux)
[![GitHub forks](https://img.shields.io/github/forks/ivan-pinatti-labs/pdf-sign-linux?logo=Github&style=for-the-badge)](https://github.com/ivan-pinatti-labs/pdf-sign-linux/forks)
[![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/ivan-pinatti-labs/pdf-sign-linux?utm_source=oss&utm_medium=github&utm_campaign=ivan-pinatti-labs%2Fpdf-sign-linux&labelColor=171717&color=FF570A&label=CodeRabbit+Reviews&style=for-the-badge)](https://coderabbit.ai)
[![SonarQube Quality Gate](https://img.shields.io/sonar/quality_gate/ivan-pinatti-labs_pdf-sign-linux?server=https%3A%2F%2Fsonarcloud.io&logo=sonarqubecloud&style=for-the-badge)](https://sonarcloud.io/project/overview?id=ivan-pinatti-labs_pdf-sign-linux)
[![SonarQube Coverage](https://img.shields.io/sonar/coverage/ivan-pinatti-labs_pdf-sign-linux?server=https%3A%2F%2Fsonarcloud.io&logo=sonarqubecloud&style=for-the-badge)](https://sonarcloud.io/component_measures?id=ivan-pinatti-labs_pdf-sign-linux&metric=coverage)

Fill in and sign PDF documents on Linux with Adobe Reader XI (the Windows
version, under Wine) inside an offline, rootless podman container.

Reader XI handles what other Linux PDF tools cannot: dynamic XFA forms, common
on Canadian government sites, which show "requires Adobe Reader 8 or higher"
everywhere else. One program does everything: open, fill in, print, place your
saved signature, save.

Requirements: podman (rootless), a Wayland desktop session, about 2.6 GB of
disk for the image.

## Setup

```bash
make build        # needs network once; asks you to accept Adobe's licence
make selinux      # once, needs sudo: lets Reader run with SELinux confinement
```

The build downloads Reader XI from Adobe (checking its SHA-256) and
Microsoft's core fonts (Arial, Times New Roman...; Debian's
`ttf-mscorefonts-installer` checks them), and installs both silently, which
accepts both licences. After that nothing needs the network. The fonts
matter: Reader uses Arial for documents that name Helvetica without
embedding it, exactly as on Windows. `make selinux` installs a
small policy module (`selinux/pdf_sign.cil`, explained under Isolation).

## Use

```bash
make open FILE=~/Downloads/contract.pdf
```

The file is copied into the project's `inbox/` folder; your original is never
modified. Reader opens in its own window.

### Signing a document

Sign the document itself; do not print it first. Reader adds the signature
and leaves everything else in the file as it was. (Printing rebuilds the
pages; that is only needed for the forms in the next section.)

1. **Sign** (top right) > **Place Signature**.
2. First time only: choose **Use an image** and browse to a scan of your
   signature in the inbox (`Z:\work\...`), or **Draw** / **Type** it. Reader
   saves it in the state folder, so it is still there next time.
3. Click where it goes, resize if needed.
4. **File > Save As** into the inbox (`Z:\work`), with a new name such as
   `contract-signed.pdf`. Confirm when Reader asks to finalize the signature.

### Filling in and signing a government form (XFA)

1. `make open FILE=~/Downloads/form.pdf` and fill it in (a locked form is
   unlocked automatically, see below). The first time you
   type, Reader says it cannot save the form's data: tick **Don't show
   again**, close. These forms can be printed, not saved.
2. **File > Print**, printer **Save_to_inbox**, **Print**. A PDF of the
   filled form appears in the inbox, named after the form's title and the
   time, e.g. `Application_for_Vendor_Permit-20260926-184247.pdf`. Printing
   never overwrites an existing file. You choose the final name in step 3,
   with Save As.
3. **File > Open** that PDF (in `Z:\work`) and sign it as above.

Reader cannot place a signature on the form itself (these forms allow only
typing into their fields), so the printed PDF is what gets signed. It is a
flat copy: the fields are no longer editable. Fonts, colours and images match
the form on screen.

### Locked government forms

Some forms were edited by their publisher after Adobe sealed their usage
rights, which breaks the seal ("This document enabled extended features...
no longer available"), and Reader then locks every field. When a form
carries such a seal, `make open` opens a fillable copy instead,
`<name>-unlocked.pdf` in the inbox. The copy is made with
`qpdf --remove-restrictions`, which removes only the seal; the file's own
encryption and permissions stay as they were, and those allow filling in
forms.

## Commands

| make           | pdf-sign         | What it does                                   |
| -------------- | ---------------- | ---------------------------------------------- |
| `make build`   | `pdf-sign build` | Build the image                                |
| `make rebuild` |                  | Rebuild from scratch with fresh Debian updates |
| `make selinux` |                  | Install the SELinux module (sudo, once)        |
| `make open`    | `pdf-sign open`  | Open `FILE` (or an empty Reader)               |
| `make inbox`   |                  | List the inbox                                 |

`INBOX=...` (or `PDF_SIGN_INBOX`) changes the inbox; `PDF_SIGN_GEOMETRY`
(default `1400x950`) the window size.

## Folders

| Host                                    | In the container                 | Contents                     |
| --------------------------------------- | -------------------------------- | ---------------------------- |
| `inbox/` in this project                | `/work` (`Z:\work` in Reader)    | Documents in and out         |
| `~/.local/share/pdf-sign/profile`       | `/state`                         | Reader settings (`user.reg`) |
| `~/.local/share/pdf-sign/adobe-appdata` | Reader's `AppData\Roaming\Adobe` | Your saved signature         |

The inbox holds signed documents and printed forms; clear it out when done.
Only its `README.md` is committed; git ignores everything else in it.
`PDF_SIGN_STATE` moves the state folder.

All of these are private to your user. `pdf-sign` keeps the inbox and the
state folder at `0700` (every run also tightens state written by older
versions), and everything written inside them, by `pdf-sign` or by the
container, is created `0600`. Other accounts on the machine cannot read
your signature or your documents; root still can.

The state folder stays outside the project on purpose: a coding agent
workbench that mounts this repository (such as
[devcontainer-airlock](https://github.com/ivan-pinatti-labs/devcontainer-airlock))
runs as your user, so file permissions would not keep your signature from
it. Do not point `PDF_SIGN_STATE` into the repository.

## Isolation

Each run is a fresh container (`--rm`) with:

- **No network** (`--network=none`, loopback only).
- **No capabilities** (`--cap-drop=ALL`, `no-new-privileges`), running as
  your own user (`--userns=keep-id`) so files it writes belong to you, and
  with a private umask (`--umask=0077`) so nobody else can read them.
- **Only three folders**: the inbox and the two state folders above.
- **No access to your screen or clipboard.** The container gets only the
  Wayland socket: no X11 display, D-Bus, PipeWire or screenshot portal.
  Reader runs on a private X server inside the container (a rootful
  Xwayland, shown as one window, with the matchbox window manager inside),
  so it cannot see your other windows or your clipboard, and you cannot paste
  into it from outside.
- **Printing stays inside.** A private CUPS server, run as your user, has one
  printer whose backend writes a PDF into the inbox.

SELinux stays on. The stock container type may not touch the Wayland
socket, so Reader runs as `pdf_sign_t`, defined in `selinux/pdf_sign.cil`:
a copy of `container_t` plus exactly two permissions, writing
to the compositor's socket file (`user_tmp_t`) and connecting to the
compositor (`unconfined_t`). Only the Wayland socket is mounted, so that is
the only socket those rules reach; the type still cannot read your home
files. Without the module, `make open` refuses to start (set
`PDF_SIGN_NO_SELINUX=1` to run with labeling disabled instead). Remove it
with `sudo semodule -r pdf_sign`.

The module is generated from the host's loaded policy by
`selinux/generate.sh` (it runs `setools` in a Fedora container). If a
`container-selinux` or `selinux-policy` update ever makes `make open` fail
with SELinux denials, rerun it, then `make selinux`.

Trade-offs:

- **Reader XI 11.0.00 (2012) is unpatched** and has known vulnerabilities.
  Adobe still hosts the final 11.0.23 update, but it will not install under
  Wine. This is why the container has no network and sees only the inbox.
  Open only documents you expect.
- X11 desktop sessions are refused: X11 lets any client read the whole screen
  and clipboard.
- The printed PDFs keep the text as vector outlines (sharp at any zoom), but
  it is not selectable or searchable.

## Legal

This repository contains no Adobe or Microsoft software. `make build`
downloads Adobe Reader XI from Adobe and Microsoft's core fonts from their
usual distribution points, on your machine, after you accept their licences
(Adobe's Reader licence and Microsoft's core fonts EULA).

Do not publish the built image (to GHCR, Docker Hub or anywhere else). It
contains Adobe Reader, whose licence does not allow redistribution
(section 3.3, "Distribution"), and the fonts in installed form, which their
EULA allows to be redistributed only as the original installers. The image
is also built for your own user id.

Adobe, Acrobat and Reader are trademarks of Adobe. This project is not
affiliated with or endorsed by Adobe or Microsoft.

## License

The code is licensed under the Apache License 2.0. See
[LICENSE.md](LICENSE.md) for full details, and [NOTICE.md](NOTICE.md) for the
third-party software the build installs.

## Contribute / Donate

See [CONTRIBUTING.md](CONTRIBUTING.md) to contribute. If you use this project,
entirely or partially, or get inspired by it, consider buying me a coffee or a
beer, I would really appreciate it:
[buymeacoffee.com/ivan.pinatti](https://www.buymeacoffee.com/ivan.pinatti).

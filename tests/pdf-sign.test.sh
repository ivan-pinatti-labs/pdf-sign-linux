#!/usr/bin/env bash
#
# Tests for pdf-sign, the launcher. podman is a stub: it records what it was
# asked to run and answers the launcher's probes the way each case needs
# (STUB_NO_IMAGE, STUB_LABEL_OK, STUB_UR3). The SELinux state comes from a
# file of the test's own, through PDF_SIGN_SELINUX_ENFORCE.

# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

script="${REPO}/pdf-sign"

# shellcheck disable=SC2016 # expanded by the stub, not here
stub podman '
case "$1 $2" in
"image exists") [ -z "${STUB_NO_IMAGE:-}" ]; exit ;;
"build "*) exit 0 ;;
esac
case " $* " in
*" --entrypoint true "*) [ -n "${STUB_LABEL_OK:-}" ]; exit ;;
*" --entrypoint sh "*) [ -n "${STUB_UR3:-}" ]; exit ;;
*" --entrypoint qpdf "*)
  for out; do :; done
  touch "$PDF_SIGN_INBOX/${out#/work/}"
  ;;
esac'

export PDF_SIGN_INBOX="${SCRATCH}/inbox"
export PDF_SIGN_STATE="${SCRATCH}/state"
export PDF_SIGN_SELINUX_ENFORCE="${SCRATCH}/enforce"
export XDG_RUNTIME_DIR="${SCRATCH}/run"
export WAYLAND_DISPLAY=wayland-test
mksock "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
echo 0 >"${PDF_SIGN_SELINUX_ENFORCE}"

# The last podman call, which for `open` is the one that starts Reader.
last_call() { tail -n 1 "${STUB_LOG}"; }

run "${script}"
check "no command prints usage" 0 out "pdf-sign open [FILE]"

run "${script}" --help
check "--help prints usage" 0 out "pdf-sign build [ARGS]"

run "${script}" bogus
check "an unknown command exits 2 with usage" 2 err "pdf-sign open [FILE]"

# build

STDIN="${SCRATCH}/no"
echo n >"${STDIN}"
run "${script}" build
check "build stops unless the licences are accepted" 1 err "pdf-sign: cancelled"
not_called "a cancelled build runs nothing" "podman build"

STDIN="${SCRATCH}/yes"
echo y >"${STDIN}"
run "${script}" build --no-cache
check "build asks before accepting the licences" 0 out "Adobe's licence agreement"
called "build passes its arguments and the user to podman" \
  "podman build --no-cache --build-arg UID=$(id -u) --build-arg USERNAME=$(id -un) -t localhost/pdf-sign-reader:latest ${REPO}/containers/reader"
unset STDIN

: >"${STUB_LOG}"
PDF_SIGN_ACCEPT_ADOBE_EULA=yes run "${script}" build
check "PDF_SIGN_ACCEPT_ADOBE_EULA=yes skips the question" 0 out ""
called "an accepted build runs podman build" "podman build"
if grep --quiet "licence" "${SCRATCH}/out"; then fail "accepted build still asked"; fi

# open: what it refuses

STUB_NO_IMAGE=1 run "${script}" open
check "open needs the image" 1 err "image not built yet; run: pdf-sign build"

WAYLAND_DISPLAY='' run "${script}" open
check "open needs a Wayland session" 1 err "needs a Wayland desktop session"

run "${script}" open "${SCRATCH}/absent.pdf"
check "open refuses a missing file" 1 err "no such file: ${SCRATCH}/absent.pdf"

# open: no file, SELinux not enforcing

: >"${STUB_LOG}"
run "${script}" open
check "open with no file starts Reader" 0 err ""
called "Reader gets the inbox, state and Wayland socket" \
  "-v ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:/run/user/$(id -u)/wayland-0:ro"
called "Reader runs offline" "--network=none"
if last_call | grep --quiet -- "/work/"; then fail "no file given, yet one was passed"; fi
if last_call | grep --quiet -- "--security-opt=label"; then fail "labels set without SELinux"; fi
[[ "$(stat -c %a "${PDF_SIGN_INBOX}")" == 700 ]] || fail "inbox not 0700"
[[ "$(stat -c %a "${PDF_SIGN_STATE}")" == 700 && -d "${PDF_SIGN_STATE}/adobe-appdata" ]] ||
  fail "state folder not created private"

# open: a file from elsewhere is copied into the inbox

mkdir "${SCRATCH}/elsewhere"
echo "form one" >"${SCRATCH}/elsewhere/form.pdf"
: >"${STUB_LOG}"
run "${script}" open "${SCRATCH}/elsewhere/form.pdf"
check "a file outside the inbox is copied in" 0 err "copied into inbox: ${PDF_SIGN_INBOX}/form.pdf"
cmp -s "${SCRATCH}/elsewhere/form.pdf" "${PDF_SIGN_INBOX}/form.pdf" || fail "copy differs"
last_call | grep --quiet -- " /work/form.pdf$" || fail "Reader was not given /work/form.pdf"

run "${script}" open "${SCRATCH}/elsewhere/form.pdf"
check "the same file again is not copied twice" 0 err ""
if grep --quiet "copied" "${SCRATCH}/err"; then fail "copied again"; fi

mkdir "${SCRATCH}/other"
echo "form two" >"${SCRATCH}/other/form.pdf"
run "${script}" open "${SCRATCH}/other/form.pdf"
check "a different file of the same name is refused" 1 err \
  "form.pdf already exists in ${PDF_SIGN_INBOX} with different content"

# open: a sealed form in the inbox opens from an unlocked copy

mkdir -p "${PDF_SIGN_INBOX}/sub"
echo "sealed" >"${PDF_SIGN_INBOX}/sub/sealed.pdf"
: >"${STUB_LOG}"
STUB_UR3=1 run "${script}" open "${PDF_SIGN_INBOX}/sub/sealed.pdf"
check "a sealed form opens from an unlocked copy" 0 err \
  "opening a fillable copy: ${PDF_SIGN_INBOX}/sub/sealed-unlocked.pdf"
called "the seal is removed with qpdf" \
  "--remove-restrictions /work/sub/sealed.pdf /work/sub/sealed-unlocked.pdf"
last_call | grep --quiet -- " /work/sub/sealed-unlocked.pdf$" || fail "Reader not given the copy"

touch -d '1 minute ago' "${PDF_SIGN_INBOX}/sub/sealed.pdf"
: >"${STUB_LOG}"
STUB_UR3=1 run "${script}" open "${PDF_SIGN_INBOX}/sub/sealed.pdf"
check "an up to date unlocked copy is reused" 0 err ""
not_called "no second qpdf run" "--remove-restrictions"

: >"${STUB_LOG}"
run "${script}" open "${PDF_SIGN_INBOX}/sub/sealed-unlocked.pdf"
check "an unlocked copy is opened as it is" 0 err ""
not_called "an unlocked copy is not probed for a seal" "--entrypoint sh"

# open: SELinux enforcing

echo 1 >"${PDF_SIGN_SELINUX_ENFORCE}"
: >"${STUB_LOG}"
STUB_LABEL_OK=1 run "${script}" open
check "with the module installed Reader runs as pdf_sign_t" 0 err ""
last_call | grep --quiet -- "--security-opt=label=type:pdf_sign_t" ||
  fail "Reader not labelled pdf_sign_t"

: >"${STUB_LOG}"
PDF_SIGN_NO_SELINUX=1 run "${script}" open
check "PDF_SIGN_NO_SELINUX=1 runs without labels" 0 err "running with SELinux labeling disabled"
last_call | grep --quiet -- "--security-opt=label=disable" || fail "labels not disabled"

: >"${STUB_LOG}"
run "${script}" open
check "without the module open refuses" 1 err "install the SELinux module once with: make selinux"
not_called "Reader is not started unconfined" "-e READER_GEOMETRY"

finish

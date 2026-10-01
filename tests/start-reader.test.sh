#!/usr/bin/env bash
#
# Tests for containers/reader/start-reader, the image's entrypoint. CUPS,
# Xwayland, the window manager, Wine and pgrep are stubs. sleep is one too,
# and it is what makes each wait loop go round exactly once: the first time
# it is called it brings up the CUPS socket, and the next time it brings up
# the X socket (unless STUB_X_FAILS). pgrep reports Reader as not started,
# then running twice, then gone.
#
# The script writes to the image's own fixed paths, so this runs only in the
# throwaway container `make coverage` starts.

# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_container

script="${REPO}/containers/reader/start-reader"
x_socket=/tmp/.X11-unix/X9
export X_SOCKET="${x_socket}"
export PGREP_COUNT="${SCRATCH}/pgrep-count"

stub cupsd
stub lpadmin
stub matchbox-window-manager
# shellcheck disable=SC2016 # expanded by the stubs, not here
stub wine 'echo "changed in Reader" >>"$WINEPREFIX/user.reg"'
# shellcheck disable=SC2016
stub wineserver '[ "$1" != -k ]'
# shellcheck disable=SC2016
stub Xwayland '
if [ -n "${STUB_X_FAILS:-}" ]; then echo "cannot open display" >&2; exit 1; fi
trap "exit 0" TERM
while :; do /bin/sleep 0.1; done'
# shellcheck disable=SC2016
stub sleep "
mksock() { mkdir -p \"\$(dirname \"\$1\")\"; python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' \"\$1\"; }
if [ ! -S /tmp/cups/cups.sock ]; then mksock /tmp/cups/cups.sock
elif [ \"\$1\" = 0.1 ] && [ ! -S \"\$X_SOCKET\" ] && [ -z \"\${STUB_X_FAILS:-}\" ]; then mksock \"\$X_SOCKET\"
else /bin/sleep 0.01
fi"
# shellcheck disable=SC2016
stub pgrep '
n=$(($(cat "$PGREP_COUNT" 2>/dev/null || echo 0) + 1))
echo "$n" >"$PGREP_COUNT"
[ "$n" -eq 2 ] || [ "$n" -eq 3 ]'

export XDG_RUNTIME_DIR="${SCRATCH}/run"
export WINEPREFIX="${SCRATCH}/prefix"
export DISPLAY=:0 XAUTHORITY=/nonexistent WAYLAND_DISPLAY=wayland-0
mkdir -p "${XDG_RUNTIME_DIR}" "${WINEPREFIX}"

fresh() {
  rm -rf /tmp/cups "${x_socket}" "${PGREP_COUNT}" /state/user.reg
  echo "default settings" >"${WINEPREFIX}/user.reg"
  : >"${STUB_LOG}"
}

fresh
echo "saved settings" >/state/user.reg
READER_GEOMETRY=800x600 run "${script}" /work/sub/form.pdf
check "Reader opens the file" 0 err ""
called "CUPS runs from its private configuration" \
  "cupsd -c /tmp/cups/cupsd.conf -s /tmp/cups/cups-files.conf"
called "the inbox printer is the default" "lpadmin -d Save_to_inbox"
called "Xwayland runs privately with the geometry asked for" "Xwayland :9 -geometry 800x600"
called "the file is passed to Reader as a Windows path" 'Reader 11.0/Reader/AcroRd32.exe Z:\work\sub\form.pdf'
called "Wine is waited for" "wineserver -w"
grep --quiet "^User $(id -un)$" /tmp/cups/cups-files.conf || fail "cupsd not run as the user"
printf '%s\n' "saved settings" "changed in Reader" >"${SCRATCH}/expected"
cmp -s "${SCRATCH}/expected" /state/user.reg ||
  fail "settings not restored before Reader and saved back after"

fresh
run "${script}"
check "Reader opens with no file" 0 err ""
called "no file means no path for Reader" "wine start /max /unix ${WINEPREFIX}/drive_c/Program Files (x86)/Adobe/Reader 11.0/Reader/AcroRd32.exe"
not_called "nothing after the program" "AcroRd32.exe Z:"
[[ -f /state/user.reg ]] || fail "settings not saved on a first run"

fresh
STUB_X_FAILS=1 run "${script}"
check "a failed Xwayland stops it" 1 err "start-reader: Xwayland did not start:"
check "and shows Xwayland's log" 1 err "cannot open display"
not_called "Reader is not started" "wine "

XDG_RUNTIME_DIR='' run "${script}"
check "XDG_RUNTIME_DIR is required" 1 err "XDG_RUNTIME_DIR must be set"

finish

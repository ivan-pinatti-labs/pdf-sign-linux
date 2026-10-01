# shellcheck shell=bash
#
# Shared by the shell tests (tests/*.test.sh), which source it. Each test
# runs the script under test as its own bash process, with every external
# command it would reach for (podman, Wine, CUPS, Ghostscript...) replaced by
# a stub on PATH, in a scratch directory that is removed afterwards.

set -o errexit
set -o pipefail
set -o nounset

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "${SCRATCH}"' EXIT
STUBS="${SCRATCH}/bin"
mkdir "${STUBS}"
# The stubs log every call here, one line each, for the assertions.
export STUB_LOG="${SCRATCH}/calls"
: >"${STUB_LOG}"
# PATH without the stubs, for a stub that hands a call on to the real tool.
export REAL_PATH="${PATH}"
export PATH="${STUBS}:${PATH}"
__failures=0

# stub NAME BODY: a shell script on PATH that logs its arguments and runs
# BODY.
stub() {
  printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >>"$STUB_LOG"\n%s\n' "${1}" "${2:-}" >"${STUBS}/${1}"
  chmod +x "${STUBS}/${1}"
}

# mksock PATH: a Unix socket file at PATH, for the scripts' `-S` checks.
mksock() {
  mkdir -p "$(dirname "${1}")"
  python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "${1}"
}

# run SCRIPT [ARGS...]: runs it with bash, standard input from $STDIN (empty
# by default), and records its exit status, standard output and standard
# error.
run() {
  __status=0
  bash "$@" <"${STDIN:-/dev/null}" >"${SCRATCH}/out" 2>"${SCRATCH}/err" || __status=$?
}

# check NAME STATUS STREAM TEXT: the last run exited STATUS and printed TEXT
# on STREAM (out or err).
check() {
  local name="${1}" want_status="${2}" stream="${3}" want_text="${4}"
  if [[ "${__status}" -ne "${want_status}" ]]; then
    fail "${name}: exit ${__status}, wanted ${want_status}; stderr: $(cat "${SCRATCH}/err")"
  elif [[ -n "${want_text}" ]] && ! grep --quiet --fixed-strings -- "${want_text}" "${SCRATCH}/${stream}"; then
    fail "${name}: '${want_text}' not in std${stream}"
  else
    echo "ok ${name}"
  fi
}

# called NAME TEXT: some stub call so far carried TEXT.
called() {
  if grep --quiet --fixed-strings -- "${2}" "${STUB_LOG}"; then
    echo "ok ${1}"
  else
    fail "${1}: no call with '${2}'"
  fi
}

# not_called NAME TEXT: no stub call so far carried TEXT.
not_called() {
  if grep --quiet --fixed-strings -- "${2}" "${STUB_LOG}"; then
    fail "${1}: unexpected call with '${2}'"
  else
    echo "ok ${1}"
  fi
}

fail() {
  echo "FAIL ${1}" >&2
  __failures=$((__failures + 1))
}

# Ends a test file, failing it if any check failed.
finish() {
  if [[ "${__failures}" -gt 0 ]]; then
    echo "${__failures} failed" >&2
    exit 1
  fi
}

# The scripts that run inside the Reader image write to its fixed paths
# (/work, /state, /tmp/cups, the X socket in /tmp/.X11-unix). Only the
# throwaway container `make coverage` starts has those, as empty tmpfs
# mounts; never write to them anywhere else.
require_container() {
  if [[ ! -d /work || ! -w /work || ! -d /state || ! -w /state ]]; then
    echo "$(basename "${0}"): needs writable /work and /state; run it through make coverage" >&2
    exit 1
  fi
}

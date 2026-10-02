#!/usr/bin/env bash
#
# Tests for containers/reader/inbox-backend, the CUPS backend. Ghostscript
# is a stub that copies its input to the output it was given, failing as
# STUB_GS asks; date is fixed so names are predictable. The backend writes to
# the image's fixed /work, so this runs only in the throwaway container
# `make coverage` starts.

# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_container

script="${REPO}/containers/reader/inbox-backend"

stub date 'echo 20260102-030405'
# shellcheck disable=SC2016 # expanded by the stub, not here
stub gs '
case "${STUB_GS:-}" in
fails) exit 1 ;;
vector-fails) case " $* " in *" -sDEVICE=pdfwrite "*) exit 1 ;; esac ;;
esac
while [ $# -gt 1 ]; do
  [ "$1" = -o ] && out="$2"
  shift
done
cp "$1" "$out"'

echo "%PDF job" >"${SCRATCH}/job"

run "${script}"
check "with no arguments it describes the device to CUPS" 0 out 'direct inbox "Unknown" "Save to inbox"'

run "${script}" 1 user "My Form: 1/2" 1 "" "${SCRATCH}/job"
out=/work/My_Form__1_2-20260102-030405.pdf
check "a job is saved under its title and the time" 0 err "INFO: saved ${out}"
cmp -s "${SCRATCH}/job" "${out}" || fail "the saved PDF is not the job"
[[ "$(stat -c %a "${out}")" == 600 ]] || fail "the saved PDF is not private"
[[ -f "${SCRATCH}/job" ]] || fail "the job file CUPS owns was removed"
called "converted as vectors, overprint off" "-sDEVICE=pdfwrite -dPreserveOverprintSettings=false"

run "${script}" 1 user "My Form: 1/2" 1 "" "${SCRATCH}/job"
check "a second job of the same name and time gets a counter" 0 err \
  "INFO: saved /work/My_Form__1_2-20260102-030405-2.pdf"

STDIN="${SCRATCH}/job"
run "${script}" 2 user "///" 1 ""
check "a job on standard input with no usable title is saved as printed" 0 err \
  "INFO: saved /work/printed-20260102-030405.pdf"
cmp -s "${SCRATCH}/job" /work/printed-20260102-030405.pdf || fail "standard input not saved"
unset STDIN

STUB_GS=vector-fails run "${script}" 3 user raster 1 "" "${SCRATCH}/job"
check "a job that will not convert as vectors is rendered as images" 0 err \
  "INFO: vector conversion failed, rendering pages as images"
check "and still saved" 0 err "INFO: saved /work/raster-20260102-030405.pdf"
called "rendered at 200 dpi" "-sDEVICE=pdfimage24 -r200"

STUB_GS=fails run "${script}" 4 user broken 1 "" "${SCRATCH}/job"
check "a job that will not convert at all fails" 1 err "rendering pages as images"
[[ ! -e /work/broken-20260102-030405.pdf ]] || fail "a failed job left a PDF"

finish

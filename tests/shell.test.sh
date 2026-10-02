#!/usr/bin/env bash
#
# Runs every shell test (tests/*.test.sh but this one), each as its own bash
# process, and fails if any does. `make coverage` runs this under kcov,
# which follows each test into the script it runs, and fails below 100% of
# the scripts' lines.

set -o errexit
set -o pipefail
set -o nounset

tests="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failed=0
for test in "${tests}"/*.test.sh; do
  [[ "${test}" != "${BASH_SOURCE[0]}" && "${test}" != "${tests}/shell.test.sh" ]] || continue
  echo "# $(basename "${test}")"
  bash "${test}" || failed=$((failed + 1))
done
if [[ "${failed}" -gt 0 ]]; then
  echo "${failed} test file(s) failed" >&2
  exit 1
fi

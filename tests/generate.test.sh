#!/usr/bin/env bash
#
# Tests for selinux/generate.sh. The host's policy, rpm and the Fedora
# container are stubs: podman runs the real generate.py on a small sesearch
# fixture, where the real one would run setools. cp hands every copy to the
# real cp except two: the host's loaded policy (/sys/fs/selinux/policy),
# which becomes a placeholder, and the final copy over the committed
# selinux/pdf_sign.cil, which lands in the scratch directory instead.

# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

export WRITTEN="${SCRATCH}/written.cil"
export FIXTURE="${SCRATCH}/sesearch"
export CONTAINER_SCRIPT="${SCRATCH}/container-script"
cat >"${FIXTURE}" <<'POLICY'
### versions
container-selinux-1 selinux-policy-targeted-2
### attributes
type container_t, domain;
### allow
allow container_t container_file_t:file { read write };
### transition
type_transition container_t tmp_t:file container_file_t;
POLICY

# shellcheck disable=SC2016 # expanded by the stubs, not here
stub cp '
case "$1 $2" in
"/sys/fs/selinux/policy "*) echo policy >"$2"; exit ;;
*/pdf_sign.cil" "*/selinux/pdf_sign.cil) set -- "$1" "$WRITTEN" ;;
esac
PATH="$REAL_PATH" exec cp "$@"'
stub rpm 'printf "%s\n" container-selinux-1 selinux-policy-targeted-2'
# shellcheck disable=SC2016
stub podman '
for arg; do case "$arg" in *:/w:Z) work="${arg%:/w:Z}" ;; esac; done
cat >"$CONTAINER_SCRIPT"
python3 "$work/generate.py" <"$FIXTURE" >"$work/pdf_sign.cil"'

run "${REPO}/selinux/generate.sh"
check "generate.sh reports what it wrote" 0 out "wrote ${REPO}/selinux/pdf_sign.cil ("
check "and that it compiles" 0 out "allow rules); it compiles"
called "the versions go into the container" \
  "-e VERSIONS=container-selinux-1 selinux-policy-targeted-2"
called "setools runs in Fedora" "registry.fedoraproject.org/fedora:43"
grep --quiet --fixed-strings "semodule -n -i /w/pdf_sign.cil" "${CONTAINER_SCRIPT}" ||
  fail "the container is not given the script that checks the policy compiles"
called "rpm is asked for the policy versions" "rpm -q container-selinux selinux-policy-targeted"
grep --quiet --fixed-strings "(allow pdf_sign_t container_file_t (file (read write)))" "${WRITTEN}" ||
  fail "the generated policy was not copied out"
cmp -s "${REPO}/selinux/pdf_sign.cil" "${WRITTEN}" &&
  fail "the committed pdf_sign.cil was used instead of the generated one"

finish

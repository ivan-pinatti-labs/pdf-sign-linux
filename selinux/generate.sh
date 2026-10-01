#!/usr/bin/env bash
# Regenerate pdf_sign.cil from this host's loaded SELinux policy, then check
# that it compiles. Runs setools in a Fedora container; the host needs only
# podman. Rerun after a container-selinux or selinux-policy update if
# `make open` starts failing with SELinux denials.
set -euo pipefail

here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp /sys/fs/selinux/policy "$work/policy"
cp "$here/generate.py" "$work/"
versions="$(rpm -q container-selinux selinux-policy-targeted | tr '\n' ' ')"

# The script for the container goes in on standard input, as a quoted here
# document, so nothing in it expands on the host. The command fits on one
# line because kcov (make coverage) only sees a here document that starts
# on the line a command starts on, and reads one after a continuation as
# code.
image=registry.fedoraproject.org/fedora:43
podman run --rm -i -v "$work:/w:Z" -e VERSIONS="$versions" "$image" sh -eu <<'CONTAINER'
dnf -y -q install setools-console python3 selinux-policy-targeted \
  policycoreutils container-selinux >/dev/null
{
  echo "### versions"; echo "$VERSIONS"
  echo "### attributes"; seinfo -t container_t -x /w/policy
  echo "### allow"; sesearch -A -s container_t /w/policy
  echo "### transition"; sesearch -T -s container_t /w/policy
} | python3 /w/generate.py > /w/pdf_sign.cil
semodule -n -i /w/pdf_sign.cil
CONTAINER
cp "$work/pdf_sign.cil" "$here/pdf_sign.cil"
echo "wrote $here/pdf_sign.cil ($(grep -c "^(allow" "$here/pdf_sign.cil") allow rules); it compiles"

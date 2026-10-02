"""Tests for selinux/generate.py.

The input is what selinux/generate.sh pipes in: four sections, each headed
`### <name>`, holding the package versions, `seinfo -x` for container_t, and
`sesearch -A` and `sesearch -T` output for it.
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "selinux"))

import generate


def policy(attributes: str, allow: str = "", transition: str = "") -> str:
    return (
        "### versions\ncontainer-selinux-1.0 selinux-policy-targeted-2.0 \n"
        f"### attributes\n{attributes}\n"
        f"### allow\n{allow}\n"
        f"### transition\n{transition}\n"
    )


def run(monkeypatch, capsys, text: str) -> str:
    monkeypatch.setattr(sys, "stdin", io.StringIO(text))
    generate.main()
    return capsys.readouterr().out


def test_sub_renames_only_container_t():
    assert generate.sub("container_t") == "pdf_sign_t"
    assert generate.sub("container_file_t") == "container_file_t"


def test_copies_attributes_rules_and_transitions(monkeypatch, capsys):
    out = run(
        monkeypatch,
        capsys,
        policy(
            "   type container_t, domain, container_domain;",
            "   allow container_t container_t:process { fork signal };\n"
            "   allow container_t container_file_t:file read;\n"
            "   allow container_domain proc_t:file read;\n"
            "   allow container_t nfs_t:file read; [ virt_use_nfs ]:True\n"
            "   allow container_t tmp_t:dir { search } True",
            "   type_transition container_t tmp_t:file container_file_t;\n"
            "   type_transition container_domain tmp_t:dir container_file_t;",
        ),
    )
    assert (
        "from the loaded policy (container-selinux-1.0 selinux-policy-targeted-2.0)"
        in out
    )
    assert "(typeattributeset domain (pdf_sign_t))" in out
    assert "(typeattributeset container_domain (pdf_sign_t))" in out
    assert "(allow pdf_sign_t pdf_sign_t (process (fork signal)))" in out
    assert "(allow pdf_sign_t container_file_t (file (read)))" in out
    # Rules granted to an attribute apply already, and boolean gated ones
    # are left out.
    assert "proc_t" not in out
    assert "nfs_t" not in out
    assert "(allow pdf_sign_t tmp_t" not in out
    assert "(typetransition pdf_sign_t tmp_t file container_file_t)" in out
    assert "(typetransition pdf_sign_t tmp_t dir container_file_t)" not in out
    assert "(allow pdf_sign_t unconfined_t (unix_stream_socket (connectto)))" in out


def test_named_transition_keeps_its_name(monkeypatch, capsys):
    out = run(
        monkeypatch,
        capsys,
        policy(
            "type container_t, domain;",
            transition="type_transition container_t container_t:anon_inode io_uring_t [io_uring];",
        ),
    )
    assert (
        '(typetransition pdf_sign_t pdf_sign_t anon_inode "[io_uring]" io_uring_t)'
        in out
    )


def test_reads_attributes_after_an_alias(monkeypatch, capsys):
    out = run(
        monkeypatch, capsys, policy("type container_t alias svirt_lxc_net_t, domain;")
    )
    assert "(typeattributeset domain (pdf_sign_t))" in out
    assert "svirt_lxc_net_t" not in out


def test_no_attributes_when_container_t_is_not_listed(monkeypatch, capsys):
    out = run(monkeypatch, capsys, policy("type spc_t, domain;"))
    assert "typeattributeset" not in out
    assert "(roletype system_r pdf_sign_t)" in out


def test_refuses_an_allow_rule_it_cannot_parse(monkeypatch):
    monkeypatch.setattr(
        sys,
        "stdin",
        io.StringIO(policy("", "allow container_t tmp_t:file read write;")),
    )
    with pytest.raises(
        SystemExit, match="cannot parse: allow container_t tmp_t:file read write;"
    ):
        generate.main()


def test_refuses_a_transition_it_cannot_parse(monkeypatch):
    monkeypatch.setattr(
        sys,
        "stdin",
        io.StringIO(policy("", transition="type_transition container_t tmp_t file;")),
    )
    with pytest.raises(
        SystemExit, match="cannot parse: type_transition container_t tmp_t file;"
    ):
        generate.main()

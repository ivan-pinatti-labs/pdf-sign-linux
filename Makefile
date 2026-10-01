# Shortcuts for ./pdf-sign. FILE may be anywhere; it is copied into the inbox.
#
#   make open FILE=~/Downloads/form.pdf      fill, print, sign and save
#
# checkmake reads only the first physical line of a .PHONY declaration and
# silently drops backslash continuations, so every .PHONY here is written on
# one line (checkmake#280).
.PHONY: all help build rebuild selinux open inbox coverage workbench-help

PDF_SIGN := ./pdf-sign
INBOX ?= $(CURDIR)/inbox
FILE ?=

export PDF_SIGN_INBOX := $(INBOX)

# Quote FILE so names with spaces work; pass nothing when it is empty.
file_arg = $(if $(FILE),"$(FILE)")

# Bare `make` shows the target list rather than doing something surprising.
all: help

# The workbench targets (make claude, make codex, make unlock and the rest)
# come from a devcontainer-airlock clone, by default the one next to this
# repository's main clone, so every worktree finds the same one. See
# .devcontainer/README.md.
WORKBENCH_HOME ?= $(abspath $(dir $(shell git rev-parse --path-format=absolute --git-common-dir 2>/dev/null))../devcontainer-airlock)
-include $(WORKBENCH_HOME)/host/workbench.mk

ifeq ($(wildcard $(WORKBENCH_HOME)/host/workbench.mk),)
workbench-help:
	@printf '%s\n' \
		'Workbench: no devcontainer-airlock clone at $(WORKBENCH_HOME).' \
		'  Clone ivan-pinatti-labs/devcontainer-airlock there, or set WORKBENCH_HOME,' \
		'  for make claude, make codex, make unlock and the rest (.devcontainer/README.md).'
endif

help: ## Show this help
	@echo "Usage: make <target> [FILE=path/to/file.pdf]"
	@echo
	@grep -hE '^[a-z]+:.*## ' $(firstword $(MAKEFILE_LIST)) | awk -F':.*## ' '{printf "  %-9s %s\n", $$1, $$2}'
	@echo
	@echo "Inbox: $(PDF_SIGN_INBOX)  (override with INBOX=...)"
	@echo
	@$(MAKE) --no-print-directory workbench-help

build: ## Build the image (needs network once; asks to accept the licences)
	$(PDF_SIGN) build

rebuild: ## Rebuild from scratch to pick up Debian security updates
	$(PDF_SIGN) build --no-cache --pull

selinux: ## Install the SELinux module that keeps Reader confined (sudo, once)
	sudo semodule -i selinux/pdf_sign.cil

open: ## Open a PDF in Adobe Reader: fill, print, sign, save (FILE=doc.pdf)
	$(PDF_SIGN) open $(file_arg)

inbox: ## List the inbox
	@mkdir -p "$(PDF_SIGN_INBOX)" && chmod 700 "$(PDF_SIGN_INBOX)" && ls -lh "$(PDF_SIGN_INBOX)"

# Coverage of everything this repository writes, held at 100%: the Python
# (lines and branches, .coveragerc) under coverage.py, and the shell (lines;
# kcov reports no branches for bash) under kcov. Writes the two reports
# SonarQube Cloud reads, $(COVERAGE_DIR)/coverage.xml and
# $(COVERAGE_DIR)/shell.xml, and fails if either language is under 100%.
# .github/workflows/sonarqube.yml runs this, and so does the `coverage`
# pre-push hook.
#
# Both tools run in containers that cannot see this checkout. The files git
# would commit (tracked, plus new ones not ignored) go in on standard input
# as a tar stream, and the only host path either container gets is an empty
# scratch directory for its report. Nothing else is mounted: no home
# directory, no inbox, no Wayland socket, no token, and podman passes no
# environment variable that is not named. Both drop every capability; kcov
# also gets no network and a read only root filesystem, with empty tmpfs
# mounts at /work and /state, the fixed paths the image's scripts write to.
# The Python container needs the network for its pip install. The images
# are pinned by digest, and Renovate moves the digests.
#
# The scratch directory comes from mktemp, so it lands in TMPDIR. In a
# devcontainer-airlock workbench run this as `l2 --engine --net -- make
# coverage`: the engine can only mount paths under the TMPDIR it sets.
#
# Both reports are written before either verdict is given, so CI can still
# hand SonarQube the report of a run that falls short.
COVERAGE_DIR ?= coverage
PODMAN ?= $(if $(CONTAINER_HOST),podman-remote,podman)
# renovate: datasource=docker depName=docker.io/library/python
PYTHON_IMAGE ?= docker.io/library/python:3.12-slim@sha256:f77ac9e44ae96ef2c90b8053ea08c31f8be030f824196b0ae4db6d462c84e51f
# renovate: datasource=docker depName=docker.io/kcov/kcov
KCOV_IMAGE ?= docker.io/kcov/kcov:latest@sha256:481289ae32e55e5b733019515acd10948a4f76dfed381765577db909664fc603
SHELL_SCRIPTS := pdf-sign containers/reader/start-reader containers/reader/inbox-backend selinux/generate.sh

_sources := git ls-files -z --cached --others --exclude-standard --deduplicate \
	| tar --create --owner=0 --group=0 --numeric-owner --null --files-from=- \
		--ignore-failed-read --file=-
_unpack := set -e; mkdir /tmp/w; tar -x --no-same-owner -C /tmp/w; cd /tmp/w
_locked := --cap-drop=ALL --security-opt no-new-privileges
_comma := ,
_empty :=
_space := $(_empty) $(_empty)

coverage: ## Test the scripts in containers, failing below 100% coverage
	@set -u; out="$$(mktemp -d)"; trap 'rm -rf "$$out"' EXIT; \
	mkdir "$$out/python" "$$out/shell"; py=0; sh=0; \
	$(_sources) | $(PODMAN) run --rm --interactive $(_locked) \
		-v "$$out/python:/out:rw,Z" "$(PYTHON_IMAGE)" sh -c '$(_unpack); \
			pip install --quiet --disable-pip-version-check --root-user-action=ignore \
				--require-hashes --only-binary=:all: -r tests/requirements.txt; \
			coverage run -m pytest tests -q; \
			coverage xml -q --fail-under=0 -o /out/coverage.xml; \
			coverage report' || py=$$?; \
	$(_sources) | $(PODMAN) run --rm --interactive $(_locked) \
		--network=none --read-only --tmpfs /tmp --tmpfs /work --tmpfs /state \
		-v "$$out/shell:/out:rw,Z" "$(KCOV_IMAGE)" sh -c '$(_unpack); \
			kcov --include-path=$(subst $(_space),$(_comma),$(addprefix /tmp/w/,$(SHELL_SCRIPTS))) \
				/out/kcov tests/shell.test.sh; \
			python3 scripts/kcov_to_sonar.py /tmp/w /out/kcov/shell.test.sh.*/cobertura.xml \
				/out/shell.xml $(SHELL_SCRIPTS)' || sh=$$?; \
	rm -rf "$(COVERAGE_DIR)"; mkdir -p "$(COVERAGE_DIR)"; \
	cp "$$out"/python/coverage.xml "$$out"/shell/shell.xml "$(COVERAGE_DIR)"/ 2>/dev/null || true; \
	test "$$py" -eq 0 && test "$$sh" -eq 0

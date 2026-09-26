# Shortcuts for ./pdf-sign. FILE may be anywhere; it is copied into the inbox.
#
#   make open FILE=~/Downloads/form.pdf      fill, print, sign and save
#
# checkmake reads only the first physical line of a .PHONY declaration and
# silently drops backslash continuations, so every .PHONY here is written on
# one line (checkmake#280).
.PHONY: all help build rebuild selinux open inbox workbench-help

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
	@grep -hE '^[a-z]+:.*## ' $(firstword $(MAKEFILE_LIST)) | awk -F':.*## ' '{printf "  %-8s %s\n", $$1, $$2}'
	@echo
	@echo "Inbox: $(INBOX)  (override with INBOX=...)"
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
	@mkdir -p "$(INBOX)" && ls -lh "$(INBOX)"

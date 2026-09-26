# Shortcuts for ./pdf-sign. FILE may be anywhere; it is copied into the inbox.
#
#   make open FILE=~/Downloads/form.pdf      fill, print, sign and save

PDF_SIGN := ./pdf-sign
INBOX ?= $(CURDIR)/inbox
FILE ?=

export PDF_SIGN_INBOX := $(INBOX)

# Quote FILE so names with spaces work; pass nothing when it is empty.
file_arg = $(if $(FILE),"$(FILE)")

.DEFAULT_GOAL := help
.PHONY: help build rebuild selinux open inbox

help: ## Show this help
	@echo "Usage: make <target> [FILE=path/to/file.pdf]"
	@echo
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-8s %s\n", $$1, $$2}'
	@echo
	@echo "Inbox: $(INBOX)  (override with INBOX=...)"

build: ## Build the image (needs network once; asks to accept Adobe's licence)
	$(PDF_SIGN) build

rebuild: ## Rebuild from scratch to pick up Debian security updates
	$(PDF_SIGN) build --no-cache --pull

selinux: ## Install the SELinux module that keeps Reader confined (sudo, once)
	sudo semodule -i selinux/pdf_sign.cil

open: ## Open a PDF in Adobe Reader: fill, print, sign, save (FILE=doc.pdf)
	$(PDF_SIGN) open $(file_arg)

inbox: ## List the inbox
	@mkdir -p "$(INBOX)" && ls -lh "$(INBOX)"

.DEFAULT_GOAL = get-sources
.SECONDEXPANSION:

DIST ?= fc32
VERSION := $(shell cat version)

FEDORA_SOURCES := https://src.fedoraproject.org/rpms/linux-firmware/raw/f$(subst fc,,$(DIST))/f/sources
SRC_FILE := linux-firmware-$(VERSION).tar.xz
SRC_TARFILE := linux-firmware-$(VERSION).tar
SIGN_FILE := $(SRC_TARFILE).sign

BUILDER_DIR ?= ../..
SRC_DIR ?= qubes-src

DISTFILES_MIRROR ?= https://www.kernel.org/pub/linux/kernel/firmware/
UNTRUSTED_SUFF := .UNTRUSTED

SHELL := bash

.PHONY: get-sources verify-sources clean clean-sources

ifeq ($(FETCH_CMD),)
$(error "You can not run this Makefile without having FETCH_CMD defined")
endif

.INTERMEDIATE: firmware-keyring.gpg
firmware-keyring.gpg: firmware-1-key.asc
	cat $^ | gpg --dearmor >$@

.INTERMEDIATE: $(SRC_TARFILE)$(UNTRUSTED_SUFF)
%.tar$(UNTRUSTED_SUFF): %.tar.xz$(UNTRUSTED_SUFF)
	if [ -f /usr/bin/qvm-run-vm ]; \
	then qvm-run-vm --no-gui --dispvm 2>/dev/null xzcat <$< > $@; \
	else xzcat <$< > $@; fi

$(SRC_TARFILE): $(SRC_TARFILE)$(UNTRUSTED_SUFF) $(SIGN_FILE) firmware-keyring.gpg
	gpgv --keyring ./$(word 3,$^) $(word 2,$^) $(word 1,$^) || \
	  { echo "Wrong signature on $@$(UNTRUSTED_SUFF)!"; exit 1; }
	mv $@$(UNTRUSTED_SUFF) $@

$(SRC_FILE)$(UNTRUSTED_SUFF):
	@$(FETCH_CMD) $@ -- $(DISTFILES_MIRROR)$(SRC_FILE)

$(SIGN_FILE):
	@$(FETCH_CMD) $(SIGN_FILE) -- $(DISTFILES_MIRROR)$@

get-sources: $(SRC_TARFILE)
	@true

verify-sources:
	@true

clean:
	@true

clean-sources:
	rm -f $(SRC_FILE) *$(UNTRUSTED_SUFF)

# This target is generating content locally from upstream project
# # 'sources' file. Sanitization is done but it is encouraged to perform
# # update of component in non-sensitive environnements to prevent
# # any possible local destructions due to shell rendering
# .PHONY: update-sources
update-sources:
	@$(BUILDER_DIR)/$(SRC_DIR)/builder-rpm/scripts/generate-hashes-from-sources $(FEDORA_SOURCES)

ARCH ?= amd64
OS ?= $(shell uname -s | tr '[:upper:]' '[:lower:'])

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
XARGS ?= xargs -I {}
BIN_DIR ?= ${HOME}/bin
TMP ?= /tmp

FIND_EXCLUDES ?= -not \( -name .terraform -prune \) -not \( -name .terragrunt-cache -prune \)
CURL ?= curl --fail -sSL

guard/env/%:
	@ _="$(or $($*),$(error Make/environment variable '$*' not present))"

guard/program/%:
	@ which $* > /dev/null || $(MAKE) $*/install

$(BIN_DIR):
	@ echo "[make]: Creating directory '$@'..."
	mkdir -p $@

install/pip/%: PYTHON ?= python3
install/pip/%: | guard/env/PYPI_PKG_NAME
	@ echo "[$@]: Installing $*..."
	$(PYTHON) -m pip install --user $(PYPI_PKG_NAME)
	ln -sf ~/.local/bin/$* $(BIN_DIR)/$*
	$* --version
	@ echo "[$@]: Completed successfully!"

yamllint/install:
	@ $(MAKE) install/pip/$(@D) PYPI_PKG_NAME=$(@D)

cfn-lint/install:
	@ $(MAKE) install/pip/$(@D) PYPI_PKG_NAME=$(@D)

yaml/%: FIND_YAML ?= find . $(FIND_EXCLUDES) -type f \( -name '*.yml' -o -name "*.yaml" \)
## Lints YAML files
yaml/lint: | guard/program/yamllint
yaml/lint: YAMLLINT_CONFIG ?= .yamllint.yml
yaml/lint:
	@ echo "[$@]: Running yamllint..."
	$(FIND_YAML) | $(XARGS) yamllint -c $(YAMLLINT_CONFIG) --strict {}
	@ echo "[$@]: Project PASSED yamllint test!"

cfn/%: FIND_CFN ?= find . $(FIND_EXCLUDES) -name '*.template.cfn.*' -type f
## Lints CloudFormation files
cfn/lint: | guard/program/cfn-lint
	$(FIND_CFN) | $(XARGS) cfn-lint -t {}


lint: cfn/lint yaml/lint
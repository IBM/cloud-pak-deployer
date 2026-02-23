VENVS_DIR := $(HOME)/.venv
VENV_DIR := $(VENVS_DIR)/cloud-pak-deployer-doc
.PHONY: help
help:
	@grep "^# help\:" Makefile | grep -v grep | sed 's/\# help\: //' | sed 's/\# help\://'

# help: MAINTAIN
# help: venv                           - create a clean virtual environment for development
.PHONY: venv
venv:
	@test -d "$(VENVS_DIR)" || mkdir -p "$(VENVS_DIR)"
	@rm -Rf "$(VENV_DIR)"
	@python3 -m venv "$(VENV_DIR)"
	@/bin/bash -c "source $(VENV_DIR)/bin/activate && pip3 install --upgrade pip setuptools wheel && pip3 install -r requirements.txt &&  pip install sphinx_rtd_theme "
	@echo -e "Enter virtual environment using:\n. $(VENV_DIR)/bin/activate\n"


# help: activate                       - enter existing venv
.PHONY: activate
activate:
	@echo -e "Enter virtual environment using:\n. $(VENV_DIR)/bin/activate\n"
	@. $(VENV_DIR)/bin/activate


# help: clean                          - clean all files
.PHONY: clean
clean:
	@rm -rf ./site


# help: git-clean                      - clean all files using .gitignore rules
.PHONY: git-clean
git-clean:
	@git clean -X -f -d


# help: git-scrub                      - clean all files, even untracked files
.PHONY: git-scrub
git-scrub:
	@git clean -x -f -d

# help:
# help: MKDOCS
# help: serve                          - serve project html documentation
.PHONY: serve
serve:
	@/bin/bash -c "source $(VENV_DIR)/bin/activate && mkdocs serve --livereload -t material"

# help: build                          - serve project html documentation
.PHONY: build
build:
	@/bin/bash -c "source $(VENV_DIR)/bin/activate && mkdocs build -t material"

# help: package                        - package the sources for box deployment (Red Hat sharing)
.PHONY: package
package:
	@/bin/bash -c "source $(VENV_DIR)/bin/activate && mkdocs build -t material && mkdir -p release "


# help: deploy                         - deploy project to github pages
.PHONY: deploy
deploy:
	@/bin/bash -c "source $(VENV_DIR)/bin/activate && mkdocs gh-deploy -t material --force"

# Keep these lines at the end of the file to retain output formatting.
# help:

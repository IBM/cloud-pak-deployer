.PHONY: help
help:
	@grep "^# help\:" Makefile | grep -v grep | sed 's/\# help\: //' | sed 's/\# help\://'

# help: MAINTAIN

# help: install-npm                    - perform initial installation of nvm and npm
.PHONY: install-npm
install-npm:
	@curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash; \
	. ${HOME}/.nvm/nvm.sh; \
	nvm install --lts

# help: clean                          - clean all files
.PHONY: clean
clean:
	@echo "Cleaning directories..."; \
	rm -rf ./ui/node_modules; \
	rm -rf ./ui/build; \
	rm -f ./ui/package-lock.json; \
	echo "Cleaning finished"

# help:
# help: install                        - Install the node packages
.PHONY: install
install:
	@pushd ui && rm -rf ./node_modules && npm install && popd

# help: build                          - build the production UI
.PHONY: build
build:
	@pushd ui && npm run build && popd && cp -r ui/build ./ww


# Keep these lines at the end of the file to retain output formatting.
# help:

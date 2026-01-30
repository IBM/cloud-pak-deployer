.PHONY: help
help:
	@grep "^# help\:" Makefile | grep -v grep | sed 's/\# help\: //' | sed 's/\# help\://'

<<<<<<< HEAD
=======
# help: MAINTAIN

# help: install-npm                    - perform initial installation of nvm and npm
.PHONY: install-npm
install-npm:
	@curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash; \
	. ${HOME}/.nvm/nvm.sh; \
	nvm install --lts

>>>>>>> main
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
<<<<<<< HEAD
	@pushd ui 1>/dev/null&& \
	rm -rf ./node_modules && \
	npm install && \
	popd 1>/dev/null

# help: test-web-ui                    - Run the web interface locally in test mode
.PHONY: test-web-ui
test-web-ui:
	@pushd ui 1>/dev/null; \
	npm start \
	popd 1>/dev/null

# help: test-web-server                - Run the web server locally in test mode
.PHONY: test-web-server
test-web-server:
	uv venv --allow-existing; \
	uv pip install -r requirements.txt; \
	uv run webapp.py

# help: build                          - Build the production UI
.PHONY: build
build:
	@pushd ui 1>/dev/null && \
	npm run build && \
	popd 1>/dev/null && \
	cp -r ui/build ./ww
=======
	@pushd ui && rm -rf ./node_modules && npm install && popd

# help: build                          - build the production UI
.PHONY: build
build:
	@pushd ui && npm run build && popd && cp -r ui/build ./ww

>>>>>>> main

# Keep these lines at the end of the file to retain output formatting.
# help:

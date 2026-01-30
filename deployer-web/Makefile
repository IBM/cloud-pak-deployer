.PHONY: help
help:
	@grep "^# help\:" Makefile | grep -v grep | sed 's/\# help\: //' | sed 's/\# help\://'

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

# Keep these lines at the end of the file to retain output formatting.
# help:

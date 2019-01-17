# Makefile
# Basic go commands
include .env

all:
	@make help


## env: Print out the environment variables.
env:
	@echo "--- Environment Variables ---"
	@echo "PROJECTNAME=$(PROJECTNAME)"
	@echo "GOPATH="$(GOPATH)
	@echo "EXCHANGE_PAIR="$(EXCHANGE_PAIR)

## clean: Cleans the project dependencies.
clean:
	@echo "--- Running make clean ---"
	@$(GOCLEAN)
	@rm vendor -rf
	@rm bin -rf
	#@rm Gopkg.lock
	@mkdir -p bin
	@make deps

## deps: Downloads the dependencies of the project.
deps:
	@echo "--- Running make deps ---"
	@dep ensure
	@rm -rf vendor/github.com/golang/protobuf

go-lint:
	@golint -set_exit_status ${PKG_LIST}

## lint: Lint the files
lint:
	@echo "--- Running golint ---"
	@-touch $(LINTERR)
	@-rm $(LINTERR)
	@-$(MAKE) -s go-lint 2> $(LINTERR)
	@cat $(LINTERR) | sed -e '1s/.*/\nError:\n/'  | sed 's/make\[.*/ /' | sed "/^/s/^/     /" 1>&2


go-compile:
	@$(GOBUILD) -o bin/$(BINARY_NAME)


## build: Builds the binary
build:
	@echo "--- Running make build ---"
	@-touch $(STDERR)
	@-rm $(STDERR)
	@-$(MAKE) -s go-compile 2> $(STDERR)
	@cat $(STDERR) | sed -e '1s/.*/\nError:\n/'  | sed 's/make\[.*/ /' | sed "/^/s/^/     /" 1>&2
## race: Run data race detector
race:
	@echo "--- Running Race Detector ---"
	@make env
	@make build
	@go test -race -short $(PKG_LIST)

## msan: Run memory sanitizer
msan:
	@echo "--- Running Memory sanitizer ---"
	@make env
	@make build
	#@echo tee -a ${SET_CLANG} && chmod a+x ${SET_CLANG}
	@go test -msan -short $(PKG_LIST)

## run: Runs the binary after it is built.
run:
	@echo "--- Running make run ---"
	@make env
	@make clean
	@make build
	@./bin/$(BINARY_NAME)

## test: Runs go test -v.
test:
	@echo "--- Running make test ---"
	@make env
	@make build
	@$(GOTEST) -race $(PKG_LIST) -v -coverprofile artifacts/testCoverage.txt

## test-goconvey: Runs goconvey testing tool.
test-goconvey:
	@echo "--- Running make test-goconvey ---"
	@make env
	@make clean
	@make build
	@goconvey -host 0.0.0.0 -port 9000 &

## coverage: Generate global code coverage report
coverage:
	@./tools/coverage.sh

## converage-html: Generate global code coverage report in HTML
coverage-html:
	@./tools/coverage.sh html

## start-server: Start development server. Auto-starts when code changes.
start-server:
	@echo "--- Starting Development Server ---"
	@-make watch-build 2>&1 & echo $$! > $(PID_BUILD)
	@cat $(PID_BUILD) | sed "/^/s/^/  \>  PID_BUILD: /" &
	@-make watch-lint 2>&1 & echo $$! > $(PID_LINT)
	@cat $(PID_LINT) | sed "/^/s/^/  \>  PID_LINT: /" &

## stop-server: Stop development server.
stop-server:
	@echo "--- Stopping Development Server ---"
	@-touch $(PID_BUILD)
	@-kill `cat $(PID_BUILD)` 2> /dev/null || true
	@-rm $(PID_BUILD)
	@-touch $(PID_LINT)
	@-kill `cat $(PID_LINT)` 2> /dev/null || true
	@-rm $(PID_LINT)

## restart-server: Restart development server.
restart-server:
	@echo "--- Re-starting Development Server ---"
	@make stop-server
	@make start-server

## watch-build: Run given command when code changes. watch-build
watch-build:
	@LOG=* yolo -i '*.go' -e vendor -e bin -c 'make -s build'  -a $(MACHINE_NAME):9001 &

## watch-lint: Run given command when code changes. watch-lint
watch-lint:
	@LOG=* yolo -i '*.go' -e vendor -e bin -c 'make -s lint'  -a $(MACHINE_NAME):9002 &

## help: Prints out the help.
help: Makefile
	@echo " Choose a command run in "$(PROJECTNAME)":\n"
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'

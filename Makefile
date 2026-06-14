.PHONY: all build test clean run-test run-integration

all: build

build:
	lake build

test: run-test run-integration

run-test: build
	lake exe lean-mcp-test

run-integration: build
	python3 tests/integration_test.py

clean:
	lake clean

# include .env

.PHONY: build format compile test

build:
	echo "Building contracts..."
	forge build
	echo "Building completed."

format:
	forge fmt

compile:
	echo "Compiling contracts..."
	forge compile
	echo "Compilation completed."

test:
	echo "Running tests..."
	forge test
	echo "Tests completed."
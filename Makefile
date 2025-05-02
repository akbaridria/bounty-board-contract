include .env

.PHONY: build format compile test

build:
	@echo "Building contracts..."
	forge build
	@echo "Building completed."

format:
	forge fmt

compile:
	@echo "Compiling contracts..."
	forge compile
	@echo "Compilation completed."

test:
	@echo "Running tests..."
	forge test
	@echo "Tests completed."

check-balance:
	cast balance ${ADDRESS} --ether --rpc-url ${RPC_URL}

check-wallet-address:
	cast wallet address --private-key ${PRIVATE_KEY}

check-balance-from-pk:
	$(eval ADDRESS := $(shell cast wallet address --private-key ${PRIVATE_KEY}))
	@echo "Address: ${ADDRESS}"
	@cast balance ${ADDRESS} --ether --rpc-url ${RPC_URL}

deploy:
	@echo "Deploying contracts..."
	forge create --rpc-url ${RPC_URL} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--verifier blockscout \
		--verifier-url ${BLOCKSCOUT_VERIFIER_URL} \
		src/BountyBoard.sol:BountyBoard
	@echo "Deployment completed."

verify-contract:
	forge verify-contract \
		--rpc-url ${RPC_URL} \
		${CONTRACT_ADDRESS} \
		src/BountyBoard.sol:BountyBoard \
		--verifier blockscout \
		--verifier-url ${BLOCKSCOUT_VERIFIER_URL} 

clean:
	@echo "Cleaning up..."
	forge clean
	@echo "Cleanup completed."

show-json:
	forge verify-contract \
		--show-standard-json-input \
		${CONTRACT_ADDRESS} src/BountyBoard.sol:BountyBoard \
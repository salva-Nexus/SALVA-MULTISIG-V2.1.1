# Load environment variables from .env
include .env


DEPLOY-TO-BASE-MAINNET:
	forge script script/DeployMultiSig.s.sol:DeployMultiSig --rpc-url ${BASE_MAINNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

DEPLOY-TO-BASE-TESTNET:
	forge script script/DeployMultiSig.s.sol:DeployMultiSig --rpc-url ${BASE_SEPOLIA_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

DEPLOY-TO-BNB-MAINNET:
	forge script script/DeployMultiSig.s.sol:DeployMultiSig --rpc-url ${BNB_MAINNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

DEPLOY-TO-BNB-TESTNET:
	forge script script/DeployMultiSig.s.sol:DeployMultiSig --rpc-url ${BNB_TESTNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-abi-exporter";
import "hardhat-log-remover";

dotenv.config({
  path: `.env.${process.env.NODE_ENV ? process.env.NODE_ENV : "development"}`,
});

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 999999,
      },
    },
  },
  networks: {
    "bsc-testnet": {
      url: process.env.BSC_RPC,
      accounts: [
        process.env.ADMIN_SIGNER_PRIVATE_KEY!,
        process.env.DEPLOYER_PRIVATE_KEY!,
      ],
    },
    bsc: {
      url: process.env.BSC_RPC,
      accounts: [
        process.env.ADMIN_SIGNER_PRIVATE_KEY!,
        process.env.DEPLOYER_PRIVATE_KEY!,
      ],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY,
  },
  abiExporter: {
    runOnCompile: true,
    flat: true,
    only: ["COKSNFTAirdrop", "COKSNFT", "COKSWheel"],
    except: ["ICOKSNFT"],
  },
  typechain: {
    outDir: "types",
  },
};

export default config;

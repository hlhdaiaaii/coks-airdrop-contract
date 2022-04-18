import * as dotenv from "dotenv";

import { ethers } from "hardhat";
import { COKSWheel } from "../types/COKSWheel";
import { COKSNFT__factory } from "../types/factories/COKSNFT__factory";
import { COKSWheel__factory } from "../types/factories/COKSWheel__factory";
import { COKSNFTAirdrop__factory } from "../types/factories/COKSNFTAirdrop__factory";
import { COKSNFTAirdrop } from "../types/COKSNFTAirdrop";
import { MyERC20__factory } from "../types/factories/MyERC20__factory";
import { MyERC20 } from "../types/MyERC20";

dotenv.config({
  path: `.env.${process.env.NODE_ENV ? process.env.NODE_ENV : "development"}`,
});

async function main() {
  const [adminSigner, deployer] = await ethers.getSigners();
  const TICKET_PRICE = ethers.utils.parseEther(process.env.TICKET_PRICE!);

  console.log("adminSigner: ", adminSigner.address);
  console.log("deployer: ", deployer.address);

  const airdropFactory = <COKSNFTAirdrop__factory>(
    await ethers.getContractFactory("COKSNFTAirdrop")
  );
  const nftFactory = <COKSNFT__factory>(
    await ethers.getContractFactory("COKSNFT")
  );
  const wheelFactory = <COKSWheel__factory>(
    await ethers.getContractFactory("COKSWheel")
  );

  const nft = await nftFactory.connect(deployer).deploy();
  await nft.deployed();
  console.log("nft deployed to: ", nft.address);

  const airdrop: COKSNFTAirdrop = await airdropFactory
    .connect(deployer)
    .deploy(adminSigner.address, nft.address);
  await airdrop.deployed();
  console.log("airdrop deployed to: ", airdrop.address);

  const wheel: COKSWheel = await wheelFactory.connect(deployer).deploy();
  await wheel.deployed();
  console.log("wheel deployed to: ", wheel.address);

  await airdrop.connect(deployer).setRate(73, 15, 8, 3, 1);
  await nft.connect(deployer).setRoleMinter(airdrop.address); // set minter role for airdrop contract
  await wheel
    .connect(deployer)
    .config(adminSigner.address, TICKET_PRICE, process.env.BUSD_ADDRESS!);

  if (process.env.NODE_ENV !== "production") {
    const erc20Factory: MyERC20__factory = <MyERC20__factory>(
      await ethers.getContractFactory("MyERC20")
    );

    const busd: MyERC20 = <MyERC20>(
      erc20Factory.attach(process.env.BUSD_ADDRESS!)
    );
    await busd.mint(wheel.address, ethers.utils.parseEther("9999999999"));

    console.log("mint busd for wheel contract");
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

import { ethers } from "hardhat";
import { COKSNFT__factory } from "../types/factories/COKSNFT__factory";
import { NFTAirdrop__factory } from "../types/factories/NFTAirdrop__factory";
import { NFTAirdrop } from "../types/NFTAirdrop";

async function main() {
  const [adminSigner, deployer] = await ethers.getSigners();

  console.log("adminSigner: ", adminSigner.address);
  console.log("deployer: ", deployer.address);

  const airdropFactory = <NFTAirdrop__factory>(
    await ethers.getContractFactory("NFTAirdrop")
  );
  const nftFactory = <COKSNFT__factory>(
    await ethers.getContractFactory("COKSNFT")
  );

  const nft = await nftFactory.connect(deployer).deploy();
  await nft.deployed();
  console.log("nft deployed to: ", nft.address);

  const airdrop: NFTAirdrop = await airdropFactory
    .connect(deployer)
    .deploy(adminSigner.address, nft.address);
  await airdrop.deployed();
  console.log("airdrop deployed to: ", airdrop.address);

  await airdrop.connect(deployer).setRate(73, 15, 8, 3, 1);
  await nft.connect(deployer).setRoleMinter(airdrop.address); // set minter role for airdrop contract
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

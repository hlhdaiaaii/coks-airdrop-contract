import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import * as dotenv from "dotenv";
import { solidity } from "ethereum-waffle";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import { COKSNFT__factory } from "../types/factories/COKSNFT__factory";
import { COKSNFTAirdrop__factory } from "../types/factories/COKSNFTAirdrop__factory";
import { COKSNFT } from "../types/COKSNFT";
import { COKSNFTAirdrop } from "../types/COKSNFTAirdrop";

dotenv.config();
chai.use(solidity);

describe("COKSNFTAirdrop", function () {
  let airdropFactory: COKSNFTAirdrop__factory;
  let airdrop: COKSNFTAirdrop;
  let nftFactory: COKSNFT__factory;
  let nft: COKSNFT;
  let adminSigner: Signer | SignerWithAddress;
  let deployer: Signer | SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let outsider: SignerWithAddress;

  const CLAIM_AMOUNT = 2;

  beforeEach(async function () {
    // admin = new Wallet(process.env.PRIVATE_KEY!, user1.provider);
    [adminSigner, deployer, user1, user2, outsider] = await ethers.getSigners();

    airdropFactory = <COKSNFTAirdrop__factory>(
      await ethers.getContractFactory("COKSNFTAirdrop")
    );
    nftFactory = <COKSNFT__factory>await ethers.getContractFactory("COKSNFT");

    nft = await nftFactory.connect(deployer).deploy();
    airdrop = await airdropFactory
      .connect(deployer)
      .deploy(await adminSigner.getAddress(), nft.address);

    await airdrop.connect(deployer).setRate(73, 15, 8, 3, 1);
    await nft.connect(deployer).setRoleMinter(airdrop.address); // set minter role for airdrop contract
  });

  describe("Claim", function () {
    it("should let permitted user claim", async function () {
      const messageHash = await airdrop.getMessageHash(
        user1.address,
        CLAIM_AMOUNT
      );
      console.log("messageHash: ", messageHash);

      // call api to get admin signature for permission for claiming token
      // data returned from api is guaranteed to be valid
      const adminSignature = await adminSigner.signMessage(
        ethers.utils.arrayify(messageHash)
      );
      console.log("admin: ", await adminSigner.getAddress());
      console.log("adminSignature: ", adminSignature);

      // frontend gets signature from user to prove he is authentically user1
      // const userSignature = await user1.signMessage(
      //   ethers.utils.arrayify(messageHash)
      // );
      // console.log("user: ", user1.address);
      // console.log("userSignature: ", userSignature);

      await expect(
        airdrop.connect(user1).claim(CLAIM_AMOUNT, adminSignature)
      ).to.emit(airdrop, "Claimed");

      // should not let user claim again
      await expect(
        airdrop.connect(user1).claim(CLAIM_AMOUNT, adminSignature)
      ).to.be.revertedWith("ALREADY_CLAIMED");
    });

    it("should not let one user claim another user's", async function () {
      // user2 calls api to get permission for claiming user1's tokens
      const messageHash = await airdrop.getMessageHash(
        user1.address,
        CLAIM_AMOUNT
      );
      const adminSignature = await adminSigner.signMessage(
        ethers.utils.arrayify(messageHash)
      );

      // user2 is unable to demonstrate that he is the same person as user1.
      // const userSignature = await user2.signMessage(
      //   ethers.utils.arrayify(messageHash)
      // );

      // as a result, user2 won't be able to claim user1's tokens
      await expect(
        airdrop.connect(user2).claim(CLAIM_AMOUNT, adminSignature)
      ).to.be.revertedWith("NOT_PERMITTED");

      // also, user2 won't be able to claim on behalf of user1 (i.e. tokens are still transfered to user1)
      await expect(
        airdrop.connect(user2).claim(CLAIM_AMOUNT, adminSignature)
      ).to.be.revertedWith("NOT_PERMITTED");
    });
  });
});

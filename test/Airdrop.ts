import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import * as dotenv from "dotenv";
import { solidity } from "ethereum-waffle";
import { Signer, Wallet } from "ethers";
import { ethers } from "hardhat";
import { Airdrop } from "../types/Airdrop";
import { Airdrop__factory } from "../types/factories/Airdrop__factory";

dotenv.config();
chai.use(solidity);

describe("Airdrop", function () {
  let airdropFactory: Airdrop__factory;
  let airdrop: Airdrop;
  let admin: Signer;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let outsider: SignerWithAddress;

  beforeEach(async function () {
    admin = new Wallet(process.env.PRIVATE_KEY!);

    [user1, user2, outsider] = await ethers.getSigners();

    airdropFactory = <Airdrop__factory>(
      await ethers.getContractFactory("Airdrop")
    );

    airdrop = await airdropFactory.deploy(await admin.getAddress());
  });

  describe("Claim", function () {
    it("should let permitted user claim", async function () {
      const amount = 100;

      const messageHash = await airdrop.getMessageHash(user1.address, amount);
      console.log("messageHash: ", messageHash);

      const adminSignature = await admin.signMessage(
        ethers.utils.arrayify(messageHash)
      );
      console.log("admin: ", await admin.getAddress());
      console.log("adminSignature: ", adminSignature);

      const userSignature = await user1.signMessage(
        ethers.utils.arrayify(messageHash)
      );
      console.log("user: ", user1.address);
      console.log("userSignature: ", userSignature);

      expect(
        await airdrop
          .connect(user1)
          .verify(user1.address, amount, adminSignature, userSignature)
      ).to.equal(true);
    });
  });
});

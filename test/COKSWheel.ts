import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai, { expect } from "chai";
import * as dotenv from "dotenv";
import { solidity } from "ethereum-waffle";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { COKSWheel } from "../types/COKSWheel";
import { COKSWheel__factory } from "../types/factories/COKSWheel__factory";
import { MyERC20__factory } from "../types/factories/MyERC20__factory";
import { MyERC20 } from "../types/MyERC20";

dotenv.config();
chai.use(solidity);

const REWARD_SEPARATOR = {
  CLAIM_TOKEN: "CLAIM_TOKEN",
  CLAIM_STABLE_COIN: "CLAIM_STABLE_COIN",
  CLAIM_NFT: "CLAIM_NFT",
  CLAIM_WHITELIST: "CLAIM_WHITELIST",
};

describe("COKSWheel", function () {
  let wheelFactory: COKSWheel__factory;
  let erc20Factory: MyERC20__factory;
  let wheel: COKSWheel;
  let busd: MyERC20;
  let adminSigner: SignerWithAddress;
  let deployer: SignerWithAddress;
  //   let adminSigner: Signer
  //   let deployer: Signer
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let outsider: SignerWithAddress;
  const TICKET_PRICE = ethers.utils.parseEther("1");

  beforeEach(async function () {
    // admin = new Wallet(process.env.PRIVATE_KEY!, user1.provider);
    [adminSigner, deployer, user1, user2, outsider] = await ethers.getSigners();

    wheelFactory = <COKSWheel__factory>(
      await ethers.getContractFactory("COKSWheel")
    );
    erc20Factory = <MyERC20__factory>await ethers.getContractFactory("MyERC20");

    wheel = await wheelFactory.connect(deployer).deploy();
    busd = await erc20Factory.connect(deployer).deploy("BUSD", "BUSD");

    await Promise.all([
      busd.mint(wheel.address, ethers.utils.parseEther("999")),
      wheel
        .connect(deployer)
        .config(adminSigner.address, TICKET_PRICE, busd.address),
    ]);
  });

  describe("Claim", function () {
    it("should let user claim BUSD", async function () {
      let nonce = 0;
      const amount = ethers.utils.parseEther("50");

      const messageHash = ethers.utils.keccak256(
        ethers.utils.solidityPack(
          ["string", "uint256", "address", "uint256"],
          [REWARD_SEPARATOR.CLAIM_STABLE_COIN, nonce, user1.address, amount]
        )
      );

      const adminSignature = await adminSigner.signMessage(
        ethers.utils.arrayify(messageHash)
      );

      await expect(
        wheel
          .connect(user1)
          .claimBUSD(
            REWARD_SEPARATOR.CLAIM_STABLE_COIN,
            nonce,
            amount,
            adminSignature
          )
      ).to.emit(wheel, "ClaimedBUSD");

      expect(await busd.balanceOf(user1.address)).to.equal(amount);

      // should not let user claim again
      await expect(
        wheel
          .connect(user1)
          .claimBUSD(
            REWARD_SEPARATOR.CLAIM_STABLE_COIN,
            nonce,
            amount,
            adminSignature
          )
      ).to.be.revertedWith("ALREADY_CLAIMED");
    });
  });

  describe("Buy ticket", function () {
    it("should let user buy ticket", async function () {
      const amount = 1;

      await expect(
        wheel.connect(user1).buyTicket(amount, {
          value: TICKET_PRICE.mul(amount),
        })
      ).to.emit(wheel, "BuyTicket");

      const [id, boughtAmount, price] = await wheel.transactions(
        user1.address,
        0
      );

      expect(id).to.equal(BigNumber.from(0));
      expect(boughtAmount).to.equal(BigNumber.from(amount));
      expect(price).to.equal(TICKET_PRICE);

      // should not let user claim if not enough balance
      await expect(
        wheel.connect(user1).buyTicket(amount + 1, {
          value: TICKET_PRICE.mul(amount),
        })
      ).to.revertedWith("NOT_ENOUGH_BALANCE");
    });
  });
});

import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { Hyperfund, MockHypercertMinter } from "../typechain-types";

describe("Hyperfund Contract", function () {
  let hyperfund: Hyperfund;
  let hypercertMinter: MockHypercertMinter;
  let owner: Signer;
  let manager: Signer;
  let pauser: Signer;
  let donor: Signer;
  let otherAccount: Signer;

  beforeEach(async function () {
    // Signers
    [owner, manager, pauser, donor, otherAccount] = await ethers.getSigners();

    // Deploy a mock HypercertMinter contract
    const HypercertMinter = await ethers.getContractFactory("MockHypercertMinter");
    hypercertMinter = (await HypercertMinter.deploy()) as MockHypercertMinter;

    // Deploy the Hyperfund contract
    const Hyperfund = await ethers.getContractFactory("Hyperfund");
    hyperfund = await Hyperfund.deploy(await hypercertMinter.getAddress(), 1);

    // Grant roles to specific accounts
    await hyperfund.connect(owner).grantRole(await hyperfund.MANAGER_ROLE(), await manager.getAddress());
    await hyperfund.connect(owner).grantRole(await hyperfund.PAUSER_ROLE(), await pauser.getAddress());
  });

  it("should allow a manager to set the hypercert ID", async function () {
    await hyperfund.connect(manager).setHypercertId(2);
    expect(await hyperfund.hypercertId()).to.equal(2);
  });

  it("should allow a manager to set allowed tokens", async function () {
    const tokenAddress = ethers.Wallet.createRandom().address;
    await hyperfund.connect(manager).setAllowedToken(tokenAddress, true);
    expect(await hyperfund.allowedTokens(tokenAddress)).to.equal(true);
  });

  it("should revert when trying to donate with a non-allowlisted token", async function () {
    const nonAllowedToken = ethers.Wallet.createRandom().address;
    await expect(
      hyperfund.connect(donor).donate(nonAllowedToken, ethers.parseEther("1"))
    ).to.be.revertedWith("token not allowlisted");
  });

  it("should allow a valid donation with an allowed ERC20 token", async function () {
    // Add the mock token to the allowed list
    await hyperfund.connect(manager).setAllowedToken(await hypercertMinter.getAddress(), true);

    // Mint some tokens to the donor
    await hypercertMinter.connect(owner).mint(await donor.getAddress(), ethers.parseEther("10"));
    
    // Approve the Hyperfund contract to spend tokens
  //  await hypercertMinter.connect(donor).approve(hyperfund.getAddress(), ethers.parseEther("1"));

    // Call donate
    await expect(hyperfund.connect(donor).donate(hypercertMinter.getAddress(), ethers.parseEther("1")))
      .to.emit(hyperfund, "DonationReceived") // Replace with actual event if any
      .withArgs(await donor.getAddress(), hypercertMinter.getAddress(), ethers.parseEther("1"));
  });

  it("should pause and unpause the contract by the pauser", async function () {
    await hyperfund.connect(pauser).pause();
    expect(await hyperfund.paused()).to.equal(true);

    await hyperfund.connect(pauser).unpause();
    expect(await hyperfund.paused()).to.equal(false);
  });

  it("should revert when trying to donate while paused", async function () {
    await hyperfund.connect(pauser).pause();
    const tokenAddress = ethers.Wallet.createRandom().address;
    await expect(hyperfund.connect(donor).donate(tokenAddress, ethers.parseEther("1"))).to.be.revertedWith(
      "Pausable: paused"
    );
  });
});
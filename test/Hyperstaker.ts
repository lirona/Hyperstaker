import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { Hyperstaker, MockHypercertMinter, MockERC20 } from "../typechain-types";

describe("Hyperstaker Contract", function () {
  let hyperstaker: Hyperstaker;
  let hypercertMinter: MockHypercertMinter;
  let rewardToken: MockERC20;
  let owner: Signer;
  let user: Signer;
  let manager: Signer;
  let pauser: Signer;

  const baseHypercertId = 1n << 128n;
  const rewardAmount = ethers.parseEther("1000");
  const units = 100;

  beforeEach(async function () {
    [owner, user, manager, pauser] = await ethers.getSigners();

    const HypercertMinter = await ethers.getContractFactory("MockHypercertMinter");
    hypercertMinter = await HypercertMinter.deploy();

    await hypercertMinter.mint(baseHypercertId, units);

    // Deploy a mock ERC20 token for rewards
    const RewardToken = await ethers.getContractFactory("MockERC20");
    rewardToken = await RewardToken.deploy("Reward Token", "RTK");

    // Deploy the Hyperstaker contract
    const Hyperstaker = await ethers.getContractFactory("Hyperstaker");
    hyperstaker = await Hyperstaker.deploy(
      hypercertMinter.getAddress(),
      baseHypercertId,
      rewardToken.getAddress(),
      rewardAmount
    );

    // Transfer reward tokens to the contract for rewards distribution
    await rewardToken.transfer(hyperstaker.getAddress(), rewardAmount);
  });

  it.only("should allow a user to stake their hypercert", async function () {
    await hyperstaker.connect(user).stake(baseHypercertId);

    const stake: { totalStaked: bigint; stakedHypercertIds: bigint[] } = await hyperstaker.stakes(await user.getAddress());
    expect(stake.totalStaked).to.equal(100);
  });

  it("should allow a user to unstake their hypercert", async function () {
    await hyperstaker.connect(user).stake(baseHypercertId);

    await hyperstaker.connect(user).unstake(baseHypercertId);

    const stake = await hyperstaker.stakes(await user.getAddress());
    expect(stake.totalStaked).to.equal(0);
  });

  it("should not allow unstaking a non-staked hypercert", async function () {
    await expect(hyperstaker.connect(user).unstake(baseHypercertId)).to.be.revertedWith("Hypercert not staked");
  });

  it("should allow a user to claim rewards", async function () {
    await hyperstaker.connect(user).stake(baseHypercertId);

    const reward = await hyperstaker.calculateReward(await user.getAddress());
    expect(reward).to.be.gt(0);

    await hyperstaker.connect(user).claimReward();

    const userBalance = await rewardToken.balanceOf(await user.getAddress());
    expect(userBalance).to.equal(reward);
  });

  it("should not allow claiming rewards with already claimed hypercerts", async function () {
    await hyperstaker.connect(user).stake(baseHypercertId);

    await hyperstaker.connect(user).claimReward();
    await expect(hyperstaker.connect(user).claimReward()).to.be.revertedWith("No reward available");
  });

  it("should pause and unpause the contract", async function () {
    await hyperstaker.connect(owner).grantRole(await hyperstaker.PAUSER_ROLE(), await pauser.getAddress());
    await hyperstaker.connect(pauser).pause();
    expect(await hyperstaker.paused()).to.equal(true);

    await hyperstaker.connect(pauser).unpause();
    expect(await hyperstaker.paused()).to.equal(false);
  });

  it("should revert staking when paused", async function () {
    await hyperstaker.connect(owner).grantRole(await hyperstaker.PAUSER_ROLE(), await pauser.getAddress());
    await hyperstaker.connect(pauser).pause();

    await expect(hyperstaker.connect(user).stake(baseHypercertId)).to.be.revertedWith("Pausable: paused");
  });
});
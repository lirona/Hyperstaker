// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Hyperstaker} from "../src/Hyperstaker.sol";
import {MockHypercertMinter} from "./mocks/MockHypercertMinter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract HyperstakerTest is Test {
    Hyperstaker public hyperstaker;
    MockHypercertMinter public hypercertMinter;
    uint256 public baseHypercertId = 1 << 128;
    uint256 public fractionHypercertId = (1 << 128) + 1;

    function setUp() public {
        hypercertMinter = new MockHypercertMinter();
        hyperstaker = new Hyperstaker(address(hypercertMinter), baseHypercertId);
        hypercertMinter.setUnits(fractionHypercertId, 100);
    }

    function test_Staking() public {
        hyperstaker.stake(fractionHypercertId);
        assertEq(hyperstaker.getStake(fractionHypercertId).stakingStartTime, block.timestamp);
    }

    function test_Unstaking() public {
        hyperstaker.stake(fractionHypercertId);
        hyperstaker.unstake(fractionHypercertId);
        assertEq(hyperstaker.getStake(fractionHypercertId).stakingStartTime, 0);
    }
}

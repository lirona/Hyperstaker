// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Hyperfund} from "../src/Hyperfund.sol";
import {MockHypercertMinter} from "./mocks/MockHypercertMinter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract HyperfundTest is Test {
    Hyperfund public hyperfund;
    MockHypercertMinter public hypercertMinter;
    MockERC20 public usdc;
    uint256 public baseHypercertId = 1 << 128;
    uint256 public fractionHypercertId = (1 << 128) + 1;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC");
        hypercertMinter = new MockHypercertMinter();
    }

    function testE2EFlow() public {
        address admin = vm.addr(1);
        address manager = vm.addr(2);
        address builder = vm.addr(3);

        vm.startPrank(admin);

        hyperfund = new Hyperfund(address(hypercertMinter), baseHypercertId);

        hyperfund.hasRole(hyperfund.DEFAULT_ADMIN_ROLE(), admin);

        hyperfund.grantRole(hyperfund.MANAGER_ROLE(), manager);
        vm.stopPrank();

        vm.deal(manager, 1 ether);
        vm.startPrank(manager);

        hypercertMinter.setUnits(fractionHypercertId, 1000);

        hyperfund.setAllowedToken(address(usdc), true);

        uint256 builderHypercertFraction = fractionHypercertId + 1;

        // Transfer hypercert to builder for work
        uint256[] memory newallocations = new uint256[](2);
        newallocations[0] = 990;
        newallocations[1] = 10;
        hypercertMinter.splitFraction(builder, fractionHypercertId, newallocations);

        // Allocate funds to builder
        hyperfund.allocateFunds(builder, builderHypercertFraction, 10);

        vm.stopPrank();

        // Check allocation
        require(hypercertMinter.unitsOf(builder, builderHypercertFraction) == 10, "hypercert split failed");
        require(hyperfund.allocations(builder, builderHypercertFraction) == 10, "allocation to builder failed");

        // Send donation to pool
        usdc.mint(address(hyperfund), 1000);

        vm.startPrank(builder);

        // Builder retire hypercert for USDC
        hyperfund.retireHypercert(address(usdc), 10, builderHypercertFraction);

        require(hypercertMinter.unitsOf(builder, builderHypercertFraction) == 0, "hypercert burn failed");
        require(hyperfund.allocations(builder, builderHypercertFraction) == 0, "allocation to builder unchanged");
        require(usdc.balanceOf(builder) == 10, "hypercert retirement failed");
    }
}

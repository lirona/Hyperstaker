// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IHypercertToken} from "../../src/interfaces/IHypercertToken.sol";
import {Test, console} from "forge-std/Test.sol";

contract MockHypercertMinter is IHypercertToken {
    mapping(uint256 => mapping(address => uint256)) public unitss;

    function setUnits(uint256 tokenID, uint256 _units) external {
        unitss[tokenID][msg.sender] = _units;
    }

    function mint(uint256 tokenID, uint256 _units) external {
        unitss[tokenID][address(this)] = _units;
    }

    function splitFraction(address to, uint256 tokenID, uint256[] memory values) external {
        console.log(msg.sender);
        unitss[tokenID][msg.sender] = values[0];
        unitss[tokenID + 1][to] = values[1];
    }

    function unitsOf(uint256 tokenID) external view returns (uint256) {
        return unitss[tokenID][msg.sender];
    }

    function unitsOf(address owner, uint256 tokenID) external view returns (uint256) {
        return unitss[tokenID][owner];
    }

    function ownerOf(uint256 tokenID) external view returns (address owner) {
        return address(this);
    }

    function transferFrom(address from, address to, uint256 tokenId, uint256 units) external {}

    function burn(address account, uint256 id, uint256 amount) external {
        require(unitss[id][account] > 0);
        unitss[id][address(0)] += unitss[id][account];
        unitss[id][account] = 0;
    }
}

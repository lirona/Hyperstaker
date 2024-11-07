// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IHypercertToken} from "../interfaces/IHypercertToken.sol";

contract MockHypercertMinter is IHypercertToken {
    mapping(uint256 => uint256) public unitss;

    function setUnits(uint256 tokenID, uint256 _units) external {
        unitss[tokenID] = _units;
    }

    function mint(uint256 tokenID, uint256 _units) external {
        unitss[tokenID] = _units;
    }

    function splitFraction(
        address to,
        uint256 tokenID,
        uint256[] memory values
    ) external {
        unitss[tokenID] = values[0];
        unitss[tokenID + 1] = values[1];
    }

    function unitsOf(uint256 tokenID) external view returns (uint256) {
        return unitss[tokenID];
    }

    function ownerOf(
        uint256 tokenID
    ) external view returns (address owner) {
        return address(this);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 units
    ) external {}
}
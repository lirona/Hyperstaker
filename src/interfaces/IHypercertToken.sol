// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IHypercertToken {
    function splitFraction(address to, uint256 tokenID, uint256[] memory _values) external;
    function unitsOf(address owner, uint256 tokenID) external view returns (uint256 units);
    function unitsOf(uint256 tokenID) external view returns (uint256 units);
    function ownerOf(uint256 tokenID) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId, uint256 units) external;
    function burn(address account, uint256 id, uint256) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IHypercertToken} from "./interfaces/IHypercertToken.sol";

contract Hyperfund is AccessControl, Pausable {
    IHypercertToken public hypercertMinter;
    uint256 public hypercertId;

    // erc20 token allowlist
    mapping(address => bool) public allowedTokens;

    // // hypercert fraction token id => isClaimed
    // mapping(uint256 => bool) public isClaimed;

    // builder allocations
    mapping(address => mapping(uint256 => uint256)) public allocations;

    //Roles
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event Retired(uint256 indexed hypercertId, address indexed builder, address token, uint256 amount);
    event Allocate(uint256 hypercertId, address indexed builder, uint256 amount);
    event Withdraw(address indexed token, uint256 indexed amount, address indexed to);

    constructor(address _hypercertMinter, uint256 _hypercertId) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        hypercertId = _hypercertId;
        hypercertMinter = IHypercertToken(_hypercertMinter);
    }

    // Allocate funds to builders
    function allocateFunds(address _builder, uint256 _hypercertId, uint256 _amount) external onlyRole(MANAGER_ROLE) {
        allocations[_builder][_hypercertId] = _amount;

        emit Allocate(_hypercertId, _builder, _amount);
    }

    function retireHypercert(address _token, uint256 _amount, uint256 _id) external {
        require(hypercertMinter.unitsOf(msg.sender, _id) >= _amount);
        require(allocations[msg.sender][_id] >= _amount, "insufficient allocation");

        _retireFraction(_token, _amount, _id);
        emit Retired(_id, msg.sender, _token, _amount);
    }

    function setHypercertId(uint256 _hypercertId) external onlyRole(MANAGER_ROLE) {
        hypercertId = _hypercertId;
    }

    function setAllowedToken(address _token, bool _allowed) external onlyRole(MANAGER_ROLE) {
        allowedTokens[_token] = _allowed;
    }

    function withdrawDonations(address _token, uint256 _amount, address _to) external onlyRole(MANAGER_ROLE) {
        if (_token == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            require(IERC20(_token).transfer(_to, _amount), "transfer failed");
        }

        emit Withdraw(_token, _amount, _to);
    }

    /// @notice send a donation to the hyperfund and receive a hypercert fraction (will be deprecated after integrating Doogly)
    /// @param _token address of the token to donate, must be allowlisted. address(0) for native token
    /// @param _amount amount of the token to donate
    function donate(address _token, uint256 _amount) external payable whenNotPaused {
        require(allowedTokens[_token], "token not allowlisted");
        require(_amount != 0, "invalid amount");
        require(hypercertMinter.unitsOf(hypercertId) >= _amount, "amount accedes available supply");

        if (_token == address(0)) {
            require(msg.value == _amount, "invalid amount");
        } else {
            require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), "transfer failed");
        }

        _mintFraction(msg.sender, _amount);
    }

    function _retireFraction(address _token, uint256 _amount, uint256 _id) internal {
        allocations[msg.sender][_id] -= _amount;
        hypercertMinter.burn(msg.sender, _id, _amount);
        require(IERC20(_token).transfer(msg.sender, _amount), "retirement failed due to transfer failure");
    }

    function _mintFraction(address account, uint256 amount) internal {
        uint256[] memory newallocations = new uint256[](2);
        newallocations[0] = hypercertMinter.unitsOf(msg.sender, hypercertId) - amount;
        newallocations[1] = amount;
        hypercertMinter.splitFraction(account, hypercertId, newallocations);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}

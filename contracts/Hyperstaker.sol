// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IHypercertToken} from "./interfaces/IHypercertToken.sol";

contract Hyperstaker is AccessControl, Pausable {

    uint256 internal constant TYPE_MASK = type(uint256).max << 128;

    IHypercertToken public hypercertMinter;
    uint256 public baseHypercertId;
    uint256 public totalUnits;
    address public rewardToken;
    uint256 public totalRewards;

    // Roles
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Mapping of user addresses to their staked amount
    mapping(address => UserStake) public stakes;

    // Mapping of hypercert ids to whether they have been claimed
    mapping(uint256 => bool) public isClaimed;

    struct UserStake {
        uint256 totalStaked;
        uint256[] stakedHypercertIds;
    }

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(address _hypercertMinter, uint256 _baseHypercertId) {
        require(_getBaseType(_baseHypercertId) == _baseHypercertId, "hypercert is not a base type");
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        hypercertMinter = IHypercertToken(_hypercertMinter);
        baseHypercertId = _baseHypercertId;
        totalUnits = hypercertMinter.unitsOf(baseHypercertId);
    }

    function setReward(address _rewardToken, uint256 _rewardAmount) external onlyRole(MANAGER_ROLE) {
        totalRewards = _rewardAmount;
        rewardToken = _rewardToken;
        if (_rewardToken != address(0)) {
            IERC20(_rewardToken).transferFrom(msg.sender, address(this), _rewardAmount);
        } else {
            (bool success,) = payable(msg.sender).call{value: _rewardAmount}("");
            require(success, "Native token transfer failed");
        }
    }

    function stake(uint256 _hypercertId) external whenNotPaused {
        uint256 units = hypercertMinter.unitsOf(_hypercertId);
        require(units > 0, "No units in the hypercert");
        require(hypercertMinter.ownerOf(_hypercertId) == msg.sender, "Not the owner of the hypercert");
        require(_getBaseType(_hypercertId) == baseHypercertId, "Hypercert is not a fraction of the base hypercert");

        hypercertMinter.transferFrom(msg.sender, address(this), _hypercertId, units);
        stakes[msg.sender].totalStaked += units;
        stakes[msg.sender].stakedHypercertIds.push(_hypercertId);
        emit Staked(msg.sender, units);
    }

    function unstake(uint256 _hypercertId) external whenNotPaused {
        require(isClaimed[_hypercertId] == false, "Hypercert already claimed");

        uint256 units = hypercertMinter.unitsOf(_hypercertId);
        stakes[msg.sender].totalStaked -= units;

        // remove hypercert from staked array
        uint256 length = stakes[msg.sender].stakedHypercertIds.length;
        uint256[] storage stakedHypercertIds = stakes[msg.sender].stakedHypercertIds;
        bool found = false;
        for (uint256 i = 0; i < length; i++) {
            if (stakedHypercertIds[i] == _hypercertId) {
                stakedHypercertIds[i] = stakedHypercertIds[length - 1];
                stakedHypercertIds.pop();
                found = true;
                break;
            }
        }
        require(found, "Hypercert not staked");
        hypercertMinter.transferFrom(address(this), msg.sender, _hypercertId, units);

        emit Unstaked(msg.sender, units);
    }

    function claimReward() external whenNotPaused {
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No reward available");

        for (uint256 i = 0; i < stakes[msg.sender].stakedHypercertIds.length; i++) {
            uint256 hypercertId = stakes[msg.sender].stakedHypercertIds[i];
            require(isClaimed[hypercertId] == false, "Hypercert already claimed");
            isClaimed[hypercertId] = true;
            hypercertMinter.transferFrom(address(this), msg.sender, hypercertId, hypercertMinter.unitsOf(hypercertId));
        }

        if (rewardToken != address(0)) {
            IERC20(rewardToken).transfer(msg.sender, reward);
        } else {
            (bool success,) = payable(msg.sender).call{value: reward}("");
            require(success, "Native token transfer failed");
        }

        emit RewardClaimed(msg.sender, reward);
    }

    function calculateReward(address _user) public view returns (uint256) {
        return (stakes[_user].totalStaked * totalRewards) / totalUnits;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _getBaseType(uint256 _hypercertId) internal pure returns (uint256) {
        return _hypercertId & TYPE_MASK;
    }
}

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
    uint256 public roundStartTime;
    uint256 public roundEndTime;
    uint256 public roundDuration;

    // Roles
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Mapping of hypercert id to stake info
    mapping(uint256 => Stake) public stakes;

    struct Stake {
        bool isClaimed;
        uint256 stakingStartTime;
    }

    event Staked(uint256 indexed hypercertId);
    event Unstaked(uint256 indexed hypercertId);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardSet(address indexed token, uint256 amount);

    constructor(address _hypercertMinter, uint256 _baseHypercertId) {
        require(_getBaseType(_baseHypercertId) == _baseHypercertId, "hypercert is not a base type");
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        hypercertMinter = IHypercertToken(_hypercertMinter);
        baseHypercertId = _baseHypercertId;
        totalUnits = hypercertMinter.unitsOf(baseHypercertId);
        roundStartTime = block.timestamp;
    }

    function setReward(address _rewardToken, uint256 _rewardAmount) external payable onlyRole(MANAGER_ROLE) {
        totalRewards = _rewardAmount;
        rewardToken = _rewardToken;
        roundEndTime = block.timestamp;
        roundDuration = roundEndTime - roundStartTime;
        if (_rewardToken != address(0)) {
            bool success = IERC20(_rewardToken).transferFrom(msg.sender, address(this), _rewardAmount);
            require(success, "Reward token transfer failed");
        } else {
            require(msg.value == _rewardAmount, "Incorrect reward amount");
        }
        emit RewardSet(_rewardToken, _rewardAmount);
    }

    function stake(uint256 _hypercertId) external whenNotPaused {
        uint256 units = hypercertMinter.unitsOf(_hypercertId);
        require(units > 0, "No units in the hypercert");
        require(_getBaseType(_hypercertId) == baseHypercertId, "Wrong base hypercert");

        stakes[_hypercertId].stakingStartTime = block.timestamp;
        emit Staked(_hypercertId);
        hypercertMinter.transferFrom(msg.sender, address(this), _hypercertId, units);
    }

    function unstake(uint256 _hypercertId) external whenNotPaused {
        uint256 units = hypercertMinter.unitsOf(_hypercertId);
        delete stakes[_hypercertId].stakingStartTime;
        emit Unstaked(_hypercertId);
        hypercertMinter.transferFrom(address(this), msg.sender, _hypercertId, units);
    }

    function claimReward(uint256 _hypercertId) external whenNotPaused {
        uint256 reward = calculateReward(_hypercertId);
        require(reward != 0, "No reward available");
        require(stakes[_hypercertId].isClaimed == false, "Hypercert already claimed");
        require(stakes[_hypercertId].stakingStartTime != 0, "Hypercert not staked");

        stakes[_hypercertId].isClaimed = true;
        emit RewardClaimed(msg.sender, reward);

        hypercertMinter.transferFrom(address(this), msg.sender, _hypercertId, hypercertMinter.unitsOf(_hypercertId));

        if (rewardToken != address(0)) {
            require(IERC20(rewardToken).transfer(msg.sender, reward), "Reward token transfer failed");
        } else {
            (bool success,) = payable(msg.sender).call{value: reward}("");
            require(success, "Native token transfer failed");
        }
    }

    function calculateReward(uint256 _hypercertId) public view returns (uint256) {
        uint256 stakeDuration = roundEndTime - stakes[_hypercertId].stakingStartTime;
        return totalRewards * (hypercertMinter.unitsOf(_hypercertId) / totalUnits) * (stakeDuration / roundDuration);
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
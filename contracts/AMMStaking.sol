// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AMMStaking is ERC20 {
    address public owner;
    uint256 private rewardTokensPerBlock;

    event PoolCreated(uint256 poolId);
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );
    event HarvestRewards(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    struct Staker {
        uint256 amountDeposited;
        uint256 rewards;
        uint256 lastRewardedBlock;
        bool exists;
    }

    struct Pool {
        address tokenAddress;
        uint256 tokensStaked;
        address[] stakers;
    }

    Pool[] public pools;

    // poolId => staker address => pool staker
    mapping(uint256 => mapping(address => Staker)) public poolStakers;

    constructor(uint256 _rewardTokensPerBlock) ERC20("TitaniumSweet", "TSW") {
        owner = msg.sender;
        rewardTokensPerBlock = _rewardTokensPerBlock;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "AMMStaking: not an owner");
        _;
    }

    function createPool(address _tokenAddress) external onlyOwner {
        Pool memory pool;
        pool.tokenAddress = _tokenAddress;
        pools.push(pool);
        emit PoolCreated(pools.length - 1);
    }

    function getPool(uint256 _poolId) external view returns (Pool memory) {
        return pools[_poolId];
    }

    function getStaker(uint256 _poolId) external view returns (Staker memory) {
        return poolStakers[_poolId][msg.sender];
    }

    function deposit(uint256 _poolId, uint256 _amount) external {
        require(_amount > 0, "AMMStaking: invalid amount");
        Pool storage pool = pools[_poolId];
        Staker storage staker = poolStakers[_poolId][msg.sender];

        if (!staker.exists) {
            staker.exists = true;
            pool.stakers.push(msg.sender);
        }

        if (staker.amountDeposited == 0) {
            staker.lastRewardedBlock = block.number;
        }

        // overriding total amount
        pool.tokensStaked += _amount;

        staker.amountDeposited += _amount;

        emit Deposit(msg.sender, _poolId, _amount);

        IERC20(pool.tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    function withdraw(uint256 _poolId) public {
        Pool storage pool = pools[_poolId];
        Staker storage staker = poolStakers[_poolId][msg.sender];
        uint256 amount = staker.amountDeposited;

        harvestRewards(_poolId, amount);

        staker.amountDeposited = 0;
        pool.tokensStaked -= amount;

        emit Withdraw(msg.sender, _poolId, amount);
        IERC20(pool.tokenAddress).transfer(msg.sender, amount);
    }

    function harvestRewards(uint256 _poolId, uint256 _amount) public {
        Pool storage pool = pools[_poolId];

        require(pool.stakers.length >= 3, "AMMStaking: nr stakers < 3");

        Staker storage staker = poolStakers[_poolId][msg.sender];

        uint256 blocksSinceLastReward = block.number - staker.lastRewardedBlock;
        uint256 rewards = (_amount * blocksSinceLastReward * rewardTokensPerBlock) / pool.tokensStaked;
        staker.lastRewardedBlock = block.number;
        staker.rewards = rewards;

        emit HarvestRewards(msg.sender, _poolId, rewards);
        _mint(msg.sender, rewards);
    }
}

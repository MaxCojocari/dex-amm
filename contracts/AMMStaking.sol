// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AMMStaking is ERC20 {
    address public owner;
    uint256 private rewardTokensPerBlock;


    /*
    * @dev Emits if a new staking pool is created. 
    */
    event PoolCreated(uint256 poolId);

    /*
    * @dev Emits if staker deposited new (or extra) amount of funds. 
    */
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    
    /*
    * @dev Emits if staker withdraws his funds. 
    */
    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    /*
    * @dev Emits if staker wants to collect accumulated rewards. 
    */
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


    /*
    * @dev Creates a new staking pool and sets its parameters.
    *
    * @param _tokenAddress The address of the staked token.
    */
    function createPool(address _tokenAddress) external onlyOwner {
        Pool memory pool;
        pool.tokenAddress = _tokenAddress;
        pools.push(pool);
        emit PoolCreated(pools.length - 1);
    }


    /*
    * @dev Returns the pool with given poolId (positive integer). 
    *
    * @return The Pool struct.
    */
    function getPool(uint256 _poolId) external view returns (Pool memory) {
        return pools[_poolId];
    }


    /*
    * @dev Returns the staker with given poolId (positive integer). 
    *
    * @return The Staker struct.
    */
    function getStaker(uint256 _poolId) external view returns (Staker memory) {
        return poolStakers[_poolId][msg.sender];
    }


    /*
    * @dev Deposits the stakings in the pool with specified id. If new staker
    * entered the position, he/she is automatically added to the pool
    * together with stakings. At the same time the starting block number is fixed in Staker struct.
    * It's reseted when staker withdraws his stakings.
    *
    * @param _poolId The pool id.
    * @param _amount The amount of tokens locked in vault.
    * 
    */
    function deposit(uint256 _poolId, uint256 _amount) external {
        require(_amount > 0, "AMMStaking: invalid amount");
        Pool storage pool = pools[_poolId];
        Staker storage staker = poolStakers[_poolId][msg.sender];

        // if staker entered for the first time
        // he is included in the pool and the game starts
        if (!staker.exists) {
            staker.exists = true;
            pool.stakers.push(msg.sender);
        }

        // if staker withdrawn his deposited funds,
        // and he wants to stake again,
        // the block number in Staker struct is reseted and
        // everything starts all over again
        if (staker.amountDeposited == 0) {
            staker.lastRewardedBlock = block.number;
        }

        // staker can add extra amounts to his stake, the 
        // staker.lastRewardedBlock doesn't change
        pool.tokensStaked += _amount;
        staker.amountDeposited += _amount;

        emit Deposit(msg.sender, _poolId, _amount);

        IERC20(pool.tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }


    /*
    * @dev Withdraws all funds locked in vault.
    * 
    * @param _poolId The pool id. 
    */
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


    /*
    * @dev Computes the amount of accumulated rewards. The correspoing
    * amount of TitaniumSweet coins is minted to the staker.
    *
    * @param _poolId The pool id. 
    * @param _amount The amount of locked coins in vault. 
    */
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

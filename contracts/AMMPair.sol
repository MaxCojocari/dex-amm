// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IAMMPair.sol";
import "./libraries/AMMMath.sol";

contract AMMPair is IAMMPair, ERC20 {
    address private immutable token0;
    address private immutable token1;
    uint256 private balanceToken0;
    uint256 private balanceToken1;

    constructor(address _token0, address _token1) ERC20("LPToken", "LP") {
        require(
            _token0 != address(0) && _token1 != address(0),
            "AMMPair: zero address"
        );
        token0 = _token0;
        token1 = _token1;
    }

    function syncBalances() internal {
        balanceToken0 = IERC20(token0).balanceOf(address(this));
        balanceToken1 = IERC20(token0).balanceOf(address(this));
    }

    /*
    * @dev Adds liquidity to the pool token0-token1 (both ERC20 tokens).
    *
    * @param amount0Add Amount of first token to add.
    * @param amount1Add Amount of second token to add.
    * @param _provider The address of the liquidity provider
    * 
    * @return amount0In The real amount of token0 deposited in the pool.
    * It may be smaller than amount0Add if provider adds disproportionate amounts of liquidity.
    * @return amount1In The real amount of token1 deposited in the pool.
    * It may be smaller than amount1Add if provider adds disproportionate amounts of liquidity.
    * @return LPTokensMinted Amount of liquidity tokens minted.
    */
    function addLiquidity(
        uint256 amount0Add,
        uint256 amount1Add,
        address _provider
    )
        public
        returns (
            uint256 amount0In,
            uint256 amount1In,
            uint256 LPTokensMinted
        )
    {
        require(amount0Add > 0 && amount1Add > 0, "AMMPair: invalid amount");

        uint256 LPTokenBalance = IERC20(address(this)).totalSupply();
        
        syncBalances();

        if (LPTokenBalance == 0) {
            // the initial provider sets the pool ratio and 
            // receives the amount of LP tokens as geometric mean of both tokens
            LPTokensMinted = AMMMath.sqrt(amount0Add * amount1Add);
            amount0In = amount0Add;
            amount1In = amount1Add;
        } else {
            // by providing disproportionate liquidity, the provider
            // is penalised by receiving less LP tokens and thus,
            // receiving back less tokens than before
            LPTokensMinted = AMMMath.min(
                (LPTokenBalance * amount0Add) / balanceToken0,
                (LPTokenBalance * amount1Add) / balanceToken1
            );

            // the actual amount of tokens is computed proportional
            // to the amount of LP tokens minted
            amount0In = (balanceToken0 * LPTokensMinted) / LPTokenBalance;
            amount1In = (balanceToken1 * LPTokensMinted) / LPTokenBalance;
        }

        IERC20(token0).transferFrom(_provider, address(this), amount0Add);
        IERC20(token1).transferFrom(_provider, address(this), amount1Add);
        
        _mint(_provider, LPTokensMinted);

        // even though the amount of liquidity breaks the ratio
        // the extra tokens may be given back to LP providers as reward fee
        balanceToken0 += amount0Add;
        balanceToken1 += amount1Add;
    }


    /*
    * @dev Removes liquidity from the pool.
    * 
    * @param LPTokensToBurn The amount of liquidity tokens to burn.
    * @param _account The address of the account which burns the LP tokens.
    *
    * @return amount0out The amount of first token returned to _account.
    * @return amount1out The amount of second token returned to _account.
    */
    function removeLiquidity(uint256 LPTokensBurn, address _account)
        public
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        require(LPTokensBurn > 0, "AMMPair: invalid amount");
        require(
            LPTokensBurn <= IERC20(address(this)).balanceOf(_account),
            "AMMPair: insuffcient amount of LP tokens"
        );

        uint256 currentLPBalance = IERC20(address(this)).totalSupply();
        
        syncBalances();

        // the amount of tokens returned out is proportional 
        // to the amount of LP tokens minted
        amount0Out = (balanceToken0 * LPTokensBurn) / currentLPBalance;
        amount1Out = (balanceToken1 * LPTokensBurn) / currentLPBalance;

        _burn(_account, LPTokensBurn);

        IERC20(token0).transfer(_account, amount0Out);
        IERC20(token1).transfer(_account, amount1Out);
        
        balanceToken0 -= amount0Out;
        balanceToken1 -= amount1Out;
    }


    /*
    * @dev Swaps provided token for another token according to pool ratio.
    * 
    * @param _tokenIn The address of token to sell. It must be present in the pool.
    * @param amount The amount of token to swap.
    * @param choiceAssetFee The address of token chosen for fee payments.
    * @param _account The address of account who provides tokens to be swaped.
    *
    * @return amountIn The amount of token provided for swap.
    * @return amountOut The amount of token given.
    */
    function swap(
        address _tokenIn,
        uint256 amount,
        address choiceAssetFee,
        address _account
    ) external returns (uint256 amountIn, uint256 amountOut) {
        require(
            _tokenIn == token0 || _tokenIn == token1,
            "AMMPair: token inexistent in pair"
        );
        require(
            choiceAssetFee == token0 || choiceAssetFee == token1,
            "AMMPair: token inexistent in pair"
        );
        require(amount > 0, "AMMPair: invalid amount");

        syncBalances();

        address tokenIn;
        address tokenOut;
        bool isTokenInToken0 = _tokenIn == token0;

        // we need to determine which of tokenIn or 
        // tokenOut is either token0, or token1
        (tokenIn, tokenOut) = isTokenInToken0
            ? (token0, token1)
            : (token1, token0);

        // if the chosen tokens for fee is tokenIn, than tax the fees,
        // else return the initial amount
        amountIn = (choiceAssetFee == tokenIn) ? (amount * 997) / 1000 : amount;

        // compute the amount of token given out using the constant product formula
        amountOut = isTokenInToken0
            ? (balanceToken1 * amountIn) / (balanceToken0 + amountIn)
            : (balanceToken0 * amountIn) / (balanceToken1 + amountIn);

        if (choiceAssetFee == tokenOut) {
            amountOut = (amountOut * 997) / 1000;
        }

        require(amountOut > 0, "AMMPair: insufficient output amount");

        IERC20(tokenIn).transferFrom(_account, address(this), amount);
        IERC20(tokenOut).transfer(_account, amountOut);

        // update the pool reserves
        balanceToken0 = isTokenInToken0
            ? (balanceToken0 + amount)
            : (balanceToken0 - amountOut);
        balanceToken1 = isTokenInToken0
            ? (balanceToken1 - amountOut)
            : (balanceToken1 + amount);
    }


    /*
    * @dev Returns the price of token according to the token ratio in the pool. 
    *
    * @param _token Address of token which price should be returned.
    * @return The price of token.
    */
    function getPrice(address _token) external view returns (uint256) {
        require(
            _token == token0 || _token == token1,
            "AMMPair: token inexistent in pair"
        );

        // here is used an extra multipier (10^9) in order to preserve
        // the numerical precision in computations
        return
            _token == token0
                ? (balanceToken1 * 10**9) / balanceToken0
                : ((balanceToken0 * 10**9) / balanceToken1);
    }


    /*
    * @dev Sends liquidity tokens to specified address. 
    *  
    * @param amountLPTokens Amount of LP tokens to send. 
    * @param _from The address of account from which LP tokens are transferred. 
    * @param _to The address of account to which LP tokens are transferred. 
    *  
    * @return The bool variable which shows if the transfer succeeeded. 
    */
    function sendLiquidity(
        uint256 amountLPTokens,
        address _from,
        address _to
    ) public returns (bool) {
        require(amountLPTokens > 0, "AMMPair: zero amount");
        require(_from != address(0), "AMMPair: transfer from zero address");
        require(_to != address(0), "AMMPair: transfer to zero address");

        IERC20(address(this)).transferFrom(_from, _to, amountLPTokens);
        return true;
    }
}

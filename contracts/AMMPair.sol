// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAMMPair {
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
        external
        returns (
            uint256 amount0In,
            uint256 amount1In,
            uint256 LPTokensMinted
        );


    /*
    * @dev Removes liquidity from the pool
    * 
    * @param LPTokensToBurn The amount of liquidity tokens to burn.
    * @param _account The address of the account which burns the LP tokens.
    *
    * @return amount0out The amount of first token returned to _account.
    * @return amount1out The amount of second token returned to _account.
    */
    function removeLiquidity(uint256 LPTokensToBurn, address _account)
        external
        returns (uint256 amount0Out, uint256 amount1Out);


    /*
    * @dev Returns the price of token according to the token ratio in the pool. 
    *
    * @param _token Address of token which price should be returned.
    * @return The price of token.
    */
    function getPrice(address _token) external view returns (uint256);


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
    ) external returns (uint256 amountIn, uint256 amountOut);


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
    ) external returns (bool);
}

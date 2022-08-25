// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IAMMPair.sol";
import "./interfaces/IAMMFactory.sol";
import "./interfaces/IAMMPairETH.sol";
import "./interfaces/IAMMFactoryETH.sol";

contract AMMRouter {
    address private immutable factory;
    address private immutable factoryETH;

    constructor(address _factory, address _factoryETH) {
        factory = _factory;
        factoryETH = _factoryETH;
    }


    /*
    * @dev Creates a new pool for given pair of ERC20 tokens.
    *
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    * 
    * @return pair The address of the new pool.
    */
    function createPool(address _token0, address _token1)
        public
        returns (address pair)
    {
        require(
            IAMMFactory(factory).getAddressPair(_token0, _token1) == address(0),
            "AMMRouter: pair already exists"
        );
        pair = IAMMFactory(factory).addPair(_token0, _token1);
    }


    /*
    * @dev Creates a new pool for pairs ETH - ERC20 token.
    *
    * @param _token The address of the token contract.
    * 
    * @return pair The address of the new pool.
    */
    function createPoolETH(address _token) public returns (address pair) {
        require(
            IAMMFactoryETH(factoryETH).getAddressPair(_token) == address(0),
            "AMMRouter: pair already exists"
        );
        pair = IAMMFactoryETH(factoryETH).addPair(_token);
    }


    /*
    * @dev Returns the address of the pool contract for specific pair of tokens.
    * Zero address is returned if pool doesn't exist.
    *
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    *
    * @return The address of the pool contract.
    */   
    function getPair(address _token0, address _token1)
        public
        view
        returns (address)
    {
        return IAMMFactory(factory).getAddressPair(_token0, _token1);
    }


    /*
    * @dev Returns the address of the pool contract for specific pair ETH - token.
    * Zero address is returned if pool doesn't exist.
    *
    * @param _token The address of token contract.
    *
    * @return The address of the pool contract.
    */
    function getPairETH(address _token) public view returns (address) {
        return IAMMFactoryETH(factoryETH).getAddressPair(_token);
    }


    /*
    * @dev Adds liquidity to the pool _token0 - _token1.
    *
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    * @param amount0Add Amount of first token to add.
    * @param amount1Add Amount of second token to add.
    * 
    * @return amount0In The real amount of token0 deposited in the pool.
    * It may be smaller than amount0Add if provider adds disproportionate amounts of liquidity.
    * @return amount1In The real amount of token1 deposited in the pool.
    * It may be smaller than amount1Add if provider adds disproportionate amounts of liquidity.
    * @return LPTokensMinted Amount of liquidity tokens minted.
    */
    function addLiquidity(
        address _token0,
        address _token1,
        uint256 amount0Add,
        uint256 amount1Add
    )
        public
        returns (
            uint256 amount0In,
            uint256 amount1In,
            uint256 LPTokensMinted
        )
    {
        (amount0In, amount1In, LPTokensMinted) = IAMMPair(
            getPair(_token0, _token1)
        ).addLiquidity(amount0Add, amount1Add, msg.sender);
    }


    /*
    * @dev Adds liquidity to the pool ETH - ERC20 token.
    *
    * @param _token The token's address.
    * @param amountTokenAdd The amount of token to add.
    * 
    * @return amountTokenIn The real amount of token deposited in the pool.
    * It may be smaller than amountTokenAdd if provider adds disproportionate amounts of liquidity.
    * @return amountETHIn The real amount of ETH deposited in the pool.
    * It may be smaller than msg.value if provider adds disproportionate amounts of liquidity.
    * @return LPTokensMinted Amount of liquidity tokens minted.
    */
    function addLiquidityETH(address _token, uint256 amountTokenAdd)
        public
        payable
        returns (
            uint256 amountTokenIn,
            uint256 amountETHIn,
            uint256 LPTokensMinted
        )
    {
        (amountTokenIn, amountETHIn, LPTokensMinted) = IAMMPairETH(
            getPairETH(_token)
        ).addLiquidity{value: msg.value}(amountTokenAdd, msg.sender);
    }


    /*
    * @dev Removes liquidity from the token-token pool.
    * 
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    * @param LPTokensToBurn The amount of liquidity tokens to burn.
    *
    * @return amount0out The amount of first token returned to _account.
    * @return amount1out The amount of second token returned to _account.
    */
    function removeLiquidity(
        address _token0,
        address _token1,
        uint256 LPTokensToBurn
    ) public returns (uint256 amount0Out, uint256 amount1Out) {
        (amount0Out, amount1Out) = IAMMPair(getPair(_token0, _token1))
            .removeLiquidity(LPTokensToBurn, msg.sender);
    }


    /*
    * @dev Removes liquidity from the ETH - token pool.
    * 
    * @param _token The token's address.
    * @param LPTokensToBurn The amount of liquidity tokens to burn.
    *
    * @return amountTokenout The amount of token returned to _account.
    * @return amountETHout The amount of ETH returned to _account.
    */
    function removeLiquidityETH(address _token, uint256 LPTokenBurn)
        public
        returns (uint256 amountTokenOut, uint256 amountETHOut)
    {
        (amountTokenOut, amountETHOut) = IAMMPairETH(getPairETH(_token))
            .removeLiquidity(LPTokenBurn, msg.sender);
    }


    /*
    * @dev Swaps provided token for another token according to pool ratio (pools token-token).
    * 
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    * @param _tokenIn The address of token to sell. It must be present in the pool.
    * @param amount The amount of token to swap.
    * @param choiceAssetFee The address of token chosen for fee payments.
    *
    * @return amountIn The amount of token provided for swap.
    * @return amountOut The amount of token given.
    */
    function swap(
        address _token0,
        address _token1,
        address _tokenIn,
        uint256 amount,
        address choiceAssetFee
    ) public returns (uint256 amountIn, uint256 amountOut) {
        (amountIn, amountOut) = IAMMPair(getPair(_token0, _token1)).swap(
            _tokenIn,
            amount,
            choiceAssetFee,
            msg.sender
        );
    }


    /*
    * @dev Swaps amount of ETH for the corresponding amount of token. The amount 
    * of ETH to be swap is taken from msg.value.
    * 
    * @param _token The token's address.
    * @param choiceETHFee The bool value which sets if ETH is chosen for fee payments. 
    *
    * @return amountTokenOut The amount of given token.
    */
    function swapETHForToken(address _token, bool choiceETHFee)
        public
        payable
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = IAMMPairETH(getPairETH(_token)).swapETHForToken{
            value: msg.value
        }(choiceETHFee, msg.sender);
    }


    /*
    * @dev Swaps amount of token for the corresponding amount of ETH.
    * 
    * @param _token The token's address.
    * @param amount The amount of token to swap.
    * @param choiceETHFee The bool value which sets if ETH is chosen for fee payments. 
    *
    * @return amountETHOut The amount of ETH given to _account.
    */
    function swapTokenForETH(
        address _token,
        uint256 amount,
        bool choiceETHFee
    ) public returns (uint256 amountETHOut) {
        amountETHOut = IAMMPairETH(getPairETH(_token)).swapTokenForETH(
            amount,
            choiceETHFee,
            msg.sender
        );
    }


    /*
    * @dev Sends liquidity tokens to specified address (pools token-token). 
    *  
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    * @param amountLPTokens Amount of LP tokens to send. 
    * @param _to The address of account to which LP tokens are transferred. 
    *  
    * @return The bool variable which shows if the transfer succeeded. 
    */
    function sendLiquidity(
        address _token0,
        address _token1,
        uint256 amountLPTokens,
        address _to
    ) public returns (bool success) {
        success = IAMMPair(getPair(_token0, _token1)).sendLiquidity(
            amountLPTokens,
            msg.sender,
            _to
        );
    }


    /*
    * @dev Sends liquidity tokens to specified address (pools ETH - token). 
    *  
    * @param _token The token's address. 
    * @param amountLPTokens Amount of LP tokens to send. 
    * @param _to The address of account to which LP tokens are transferred. 
    * 
    * @return The bool variable which shows if the transfer succeeded. 
    */
    function sendLiquidityETH(
        address _token,
        uint256 amountLPTokens,
        address _to
    ) public returns (bool success) {
        success = IAMMPairETH(getPairETH(_token)).sendLiquidity(
            amountLPTokens,
            msg.sender,
            _to
        );
    }


    /*
    * @dev Returns the price of token according to the token ratio in the pool (pools token-token). 
    *
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    * @param mainToken Address of token which price should be returned.
    *
    * @return The price of token.
    */
    function getPrice(
        address _token0,
        address _token1,
        address mainToken
    ) public view returns (uint256) {
        return IAMMPair(getPair(_token0, _token1)).getPrice(mainToken);
    }


    /*
    * @dev Returns the price of token or ETH based on the pool ratio (pools ETH - token). 
    *
    * @param _token The token's address.
    * @param choiceETH The bool value which sets if ETH is chosen for fee payments.
    * 
    * @return The price of token or ETH.
    */
    function getPriceETH(address _token, bool choiceETH)
        public
        view
        returns (uint256)
    {
        return IAMMPairETH(getPairETH(_token)).getPrice(choiceETH);
    }
}

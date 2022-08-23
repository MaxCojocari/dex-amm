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

    function createPoolETH(address _token) public returns (address pair) {
        require(
            IAMMFactoryETH(factoryETH).getAddressPair(_token) == address(0),
            "AMMRouter: pair already exists"
        );
        pair = IAMMFactoryETH(factoryETH).addPair(_token);
    }

    function getPair(address _token0, address _token1)
        public
        view
        returns (address)
    {
        return IAMMFactory(factory).getAddressPair(_token0, _token1);
    }

    function getPairETH(address _token) public view returns (address) {
        return IAMMFactoryETH(factoryETH).getAddressPair(_token);
    }

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

    function removeLiquidity(
        address _token0,
        address _token1,
        uint256 LPTokensToBurn
    ) public returns (uint256 amount0Out, uint256 amount1Out) {
        (amount0Out, amount1Out) = IAMMPair(getPair(_token0, _token1))
            .removeLiquidity(LPTokensToBurn, msg.sender);
    }

    function removeLiquidityETH(address _token, uint256 LPTokenBurn)
        public
        returns (uint256 amountTokenOut, uint256 amountETHOut)
    {
        (amountTokenOut, amountETHOut) = IAMMPairETH(getPairETH(_token))
            .removeLiquidity(LPTokenBurn, msg.sender);
    }

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

    function swapETHForToken(address _token, bool choiceETHFee)
        public
        payable
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = IAMMPairETH(getPairETH(_token)).swapETHForToken{
            value: msg.value
        }(choiceETHFee, msg.sender);
    }

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

    function getPrice(
        address _token0,
        address _token1,
        address mainToken
    ) public view returns (uint256) {
        return IAMMPair(getPair(_token0, _token1)).getPrice(mainToken);
    }

    function getPriceETH(address _token, bool choiceETH)
        public
        view
        returns (uint256)
    {
        return IAMMPairETH(getPairETH(_token)).getPrice(choiceETH);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAMMRouter {
    function createPool(address _token0, address _token1)
        external
        returns (address pair);

    function addLiquidity(
        address _token0,
        address _token1,
        uint256 amount0Add,
        uint256 amount1Add
    )
        external
        returns (
            uint256 amount0In,
            uint256 amount1In,
            uint256 LPTokensMinted
        );

    function addLiquidityETH(address _token, uint256 amountTokenAdd)
        external
        payable
        returns (
            uint256 amountTokenIn,
            uint256 amountETHIn,
            uint256 LPTokensMinted
        );

    function removeLiquidityETH(address _token, uint256 LPTokenBurn)
        external
        returns (uint256 amountTokenOut, uint256 amountETHOut);

    function removeLiquidity(
        address _token0,
        address _token1,
        uint256 LPTokensToBurn
    ) external returns (uint256 amount0Out, uint256 amount1Out);

    function swap(
        address _token0,
        address _token1,
        address _tokenIn,
        uint256 amount,
        address choiceAssetFee
    ) external returns (uint256 amountIn, uint256 amountOut);

    function swapETHForToken(address _token, bool choiceETHFee)
        external
        payable
        returns (uint256 amountTokenOut);

    function swapTokenForETH(
        address _token,
        uint256 amount,
        bool choiceETHFee
    ) external returns (uint256 amountETHOut);

    function sendLiquidity(
        address _token0,
        address _token1,
        uint256 amountLPTokens,
        address _to
    ) external returns (bool success);

    function sendLiquidityETH(
        address _token,
        uint256 amountLPTokens,
        address _to
    ) external;

    function getPrice(
        address _token0,
        address _token1,
        address mainToken
    ) external view returns (uint256 price);

    function getPriceETH(address _token, bool choiceETH)
        external
        view
        returns (uint256 price);
}

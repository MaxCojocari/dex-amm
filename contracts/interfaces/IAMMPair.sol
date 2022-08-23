// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAMMPair {
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

    function removeLiquidity(uint256 LPTokensToBurn, address _account)
        external
        returns (uint256 amount0Out, uint256 amount1Out);

    function getPrice(address _token) external view returns (uint256);

    function swap(
        address _tokenIn,
        uint256 amount,
        address choiceAssetFee,
        address _account
    ) external returns (uint256 amountIn, uint256 amountOut);

    function sendLiquidity(
        uint256 amountLPTokens,
        address _from,
        address _to
    ) external returns (bool);
}

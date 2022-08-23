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

        if (LPTokenBalance == 0) {
            LPTokensMinted = AMMMath.sqrt(amount0Add * amount1Add);
            amount0In = amount0Add;
            amount1In = amount1Add;
        } else {
            LPTokensMinted = AMMMath.min(
                (LPTokenBalance * amount0Add) / balanceToken0,
                (LPTokenBalance * amount1Add) / balanceToken1
            );

            amount0In = (balanceToken0 * LPTokensMinted) / LPTokenBalance;
            amount1In = (balanceToken1 * LPTokensMinted) / LPTokenBalance;
        }

        balanceToken0 += amount0Add;
        balanceToken1 += amount1Add;

        _mint(_provider, LPTokensMinted);

        IERC20(token0).transferFrom(_provider, address(this), amount0Add);
        IERC20(token1).transferFrom(_provider, address(this), amount1Add);
    }

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

        amount0Out = (balanceToken0 * LPTokensBurn) / currentLPBalance;
        amount1Out = (balanceToken1 * LPTokensBurn) / currentLPBalance;

        balanceToken0 -= amount0Out;
        balanceToken1 -= amount1Out;

        _burn(_account, LPTokensBurn);

        IERC20(token0).transfer(_account, amount0Out);
        IERC20(token1).transfer(_account, amount1Out);
    }

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

        address tokenIn;
        address tokenOut;
        bool isTokenInToken0 = _tokenIn == token0;

        (tokenIn, tokenOut) = isTokenInToken0
            ? (token0, token1)
            : (token1, token0);

        amountIn = (choiceAssetFee == tokenIn) ? (amount * 997) / 1000 : amount;

        amountOut = isTokenInToken0
            ? (balanceToken1 * amountIn) / (balanceToken0 + amountIn)
            : (balanceToken0 * amountIn) / (balanceToken1 + amountIn);

        if (choiceAssetFee == tokenOut) {
            amountOut = (amountOut * 997) / 1000;
        }

        require(amountOut > 0, "AMMPair: insufficient output amount");

        balanceToken0 = isTokenInToken0
            ? (balanceToken0 + amount)
            : (balanceToken0 - amountOut);
        balanceToken1 = isTokenInToken0
            ? (balanceToken1 - amountOut)
            : (balanceToken1 + amount);

        IERC20(tokenIn).transferFrom(_account, address(this), amount);
        IERC20(tokenOut).transfer(_account, amountOut);
    }

    function getPrice(address _token) external view returns (uint256) {
        require(
            _token == token0 || _token == token1,
            "AMMPair: token inexistent in pair"
        );
        return
            _token == token0
                ? (balanceToken1 * 10**9) / balanceToken0
                : ((balanceToken0 * 10**9) / balanceToken1);
    }

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

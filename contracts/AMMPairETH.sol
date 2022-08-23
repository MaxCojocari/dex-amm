// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/AMMMath.sol";
import "./interfaces/IAMMPairETH.sol";

contract AMMPairETH is IAMMPairETH, ERC20 {
    address private immutable token;
    uint256 private balanceToken;
    uint256 private balanceETH;

    constructor(address _token) ERC20("LPToken", "LP") {
        require(_token != address(0), "AMMPairETH: zero address");
        token = _token;
    }

    function addLiquidity(uint256 amountTokenAdd, address _account)
        public
        payable
        returns (
            uint256 amountTokenIn,
            uint256 amountETHIn,
            uint256 LPTokensMinted
        )
    {
        require(
            amountTokenAdd > 0 && msg.value > 0,
            "AMMPairETH: invalid amount"
        );

        uint256 LPTokenBalance = IERC20(address(this)).totalSupply();

        if (LPTokenBalance == 0) {
            LPTokensMinted = AMMMath.sqrt(msg.value * amountTokenAdd);
            amountTokenIn = amountTokenAdd;
            amountETHIn = msg.value;
        } else {
            LPTokensMinted = AMMMath.min(
                (LPTokenBalance * amountTokenAdd) / balanceToken,
                (LPTokenBalance * msg.value) / balanceETH
            );

            amountTokenIn = (balanceToken * LPTokensMinted) / LPTokenBalance;
            amountETHIn = (balanceETH * LPTokensMinted) / LPTokenBalance;
        }

        balanceETH = address(this).balance;
        balanceToken += amountTokenAdd;

        _mint(_account, LPTokensMinted);

        IERC20(token).transferFrom(_account, address(this), amountTokenAdd);
    }

    function removeLiquidity(uint256 LPTokensBurn, address _account)
        public
        returns (uint256 amountTokenOut, uint256 amountETHOut)
    {
        require(LPTokensBurn > 0, "AMMPairETH: invalid amount");
        require(
            LPTokensBurn <= IERC20(address(this)).balanceOf(_account),
            "AMMPairETH: insuffcient amount of LP tokens"
        );

        uint256 LPTokenBalance = IERC20(address(this)).totalSupply();

        amountETHOut = (balanceETH * LPTokensBurn) / LPTokenBalance;
        amountTokenOut = (balanceToken * LPTokensBurn) / LPTokenBalance;

        balanceETH = address(this).balance - amountETHOut;
        balanceToken -= amountTokenOut;

        _burn(_account, LPTokensBurn);

        IERC20(token).transfer(_account, amountTokenOut);
        payable(_account).transfer(amountETHOut);
    }

    function swapETHForToken(bool choiceETHFee, address _account)
        public
        payable
        returns (uint256 amountTokenOut)
    {
        require(msg.value > 0, "AMMPairETH: invalid amount");
        uint256 amountETHIn = choiceETHFee
            ? (msg.value * 997) / 1000
            : msg.value;

        amountTokenOut =
            (balanceToken * amountETHIn) /
            (balanceETH + amountETHIn);

        amountTokenOut = !choiceETHFee
            ? (amountTokenOut * 997) / 1000
            : amountTokenOut;

        require(amountTokenOut > 0, "AMMPairETH: insufficient output amount");

        balanceETH = address(this).balance;
        balanceToken -= amountTokenOut;

        IERC20(token).transfer(_account, amountTokenOut);
    }

    function swapTokenForETH(
        uint256 amount,
        bool choiceETHFee,
        address _account
    ) public returns (uint256 amountETHOut) {
        require(amount > 0, "AMMPairETH: invalid amount");

        uint256 amountTokenIn = !choiceETHFee ? (amount * 997) / 1000 : amount;

        amountETHOut = (balanceETH * amountTokenIn) / (balanceToken + amountTokenIn);

        amountETHOut = choiceETHFee
            ? (amountETHOut * 997) / 1000
            : amountETHOut;

        require(amountETHOut > 0, "AMMPairETH: insufficient output amount");

        balanceETH = address(this).balance - amountETHOut;
        balanceToken += amount;

        IERC20(token).transferFrom(_account, address(this), amount);
        payable(_account).transfer(amountETHOut);
    }

    function getPrice(bool choiceETH) external view returns (uint256) {
        return
            choiceETH
                ? (balanceToken * 10**9) / balanceETH
                : (balanceETH * 10**9) / balanceToken;
    }

    function sendLiquidity(
        uint256 amountLPTokens,
        address _from,
        address _to
    ) public returns (bool) {
        require(amountLPTokens > 0, "AMMPairETH: invalid amount");
        require(_from != address(0), "AMMPairETH: transfer from zero address");
        require(_to != address(0), "AMMPairETH: transfer to zero address");

        IERC20(address(this)).transferFrom(_from, _to, amountLPTokens);
        return true;
    }
}

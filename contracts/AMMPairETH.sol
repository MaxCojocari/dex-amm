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


    /*
    * @dev Adds liquidity to the pool ETH - ERC20 token.
    *
    * @param amountTokenAdd Amount of token to add.
    * @param _account The address of the liquidity provider
    * 
    * @return amountTokenIn The real amount of token deposited in the pool.
    * It may be smaller than amountTokenAdd if provider adds disproportionate amounts of liquidity.
    * @return amountETHIn The real amount of ETH deposited in the pool.
    * It may be smaller than msg.value if provider adds disproportionate amounts of liquidity.
    * @return LPTokensMinted Amount of liquidity tokens minted.
    */
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
        balanceToken = IERC20(token).balanceOf(address(this));        

        if (LPTokenBalance == 0) {
            // the initial provider sets the pool ratio and 
            // receives the amount of LP tokens as geometric mean of amounts of tokens and ETH
            LPTokensMinted = AMMMath.sqrt(msg.value * amountTokenAdd);
            amountTokenIn = amountTokenAdd;
            amountETHIn = msg.value;
        } else {
            // by providing disproportionate liquidity, the provider
            // is penalised by receiving less LP tokens and thus,
            // receiving back less tokens than before
            LPTokensMinted = AMMMath.min(
                (LPTokenBalance * amountTokenAdd) / balanceToken,
                (LPTokenBalance * msg.value) / balanceETH
            );

            amountTokenIn = (balanceToken * LPTokensMinted) / LPTokenBalance;
            amountETHIn = (balanceETH * LPTokensMinted) / LPTokenBalance;
        }

        IERC20(token).transferFrom(_account, address(this), amountTokenAdd);
        
        _mint(_account, LPTokensMinted);

        // even though the amount of liquidity breaks the ratio
        // the extra tokens may be given back to LP providers as reward fee
        balanceETH = address(this).balance;
        balanceToken += amountTokenAdd;
    }


    /*
    * @dev Removes liquidity from the pool.
    * 
    * @param LPTokensToBurn The amount of liquidity tokens to burn.
    * @param _account The address of the account whose LP tokens are burnt.
    *
    * @return amountTokenout The amount of token returned to _account.
    * @return amountETHout The amount of ETH returned to _account.
    */
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
        balanceToken = IERC20(token).balanceOf(address(this));

        // the amount of tokens returned out is proportional 
        // to the amount of LP tokens minted
        amountETHOut = (balanceETH * LPTokensBurn) / LPTokenBalance;
        amountTokenOut = (balanceToken * LPTokensBurn) / LPTokenBalance;

        _burn(_account, LPTokensBurn);

        IERC20(token).transfer(_account, amountTokenOut);

        balanceToken -= amountTokenOut;
        balanceETH = address(this).balance - amountETHOut;
        
        payable(_account).transfer(amountETHOut);
    }


    /*
    * @dev Swaps amount of ETH for the corresponding amount of token. The amount 
    * of ETH to be swap is taken from msg.value.
    * 
    * @param choiceETHFee The bool value which sets if ETH is chosen for fee payments. 
    * @param _account The address of account who provides ETH to be swaped.
    *
    * @return amountTokenOut The amount of given token.
    */
    function swapETHForToken(bool choiceETHFee, address _account)
        public
        payable
        returns (uint256 amountTokenOut)
    {
        require(msg.value > 0, "AMMPairETH: invalid amount");
        
        // if the choise for fee is ETH (choiceETHFee == true), than tax the fees from msg.value,
        // else take the whole amount
        uint256 amountETHIn = choiceETHFee
            ? (msg.value * 997) / 1000
            : msg.value;

        // compute the amount of token given out using the constant product curve X * Y = K
        amountTokenOut = (balanceToken * amountETHIn) / (balanceETH + amountETHIn);

        // if the choise for fee is token (choiceETHFee == false), than tax the fees from computed,
        // token amount, otherwise no fee substraction is performed
        amountTokenOut = !choiceETHFee
            ? (amountTokenOut * 997) / 1000
            : amountTokenOut;

        require(amountTokenOut > 0, "AMMPairETH: insufficient output amount");

        IERC20(token).transfer(_account, amountTokenOut);

        // we already received ETH, no need for extra additions
        balanceETH = address(this).balance;
        balanceToken -= amountTokenOut;
    }


    /*
    * @dev Swaps amount of token for the corresponding amount of ETH.
    * The approach is pretty similar to swapETHForToken
    * 
    * @param amount The amount of token to swap.
    * @param choiceETHFee The bool value which sets if ETH is chosen for fee payments. 
    * @param _account The address of account who provides tokens to be swaped.
    *
    * @return amountETHOut The amount of ETH given to _account.
    */
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

        IERC20(token).transferFrom(_account, address(this), amount);

        balanceToken += amount;
        balanceETH = address(this).balance - amountETHOut;

        payable(_account).transfer(amountETHOut);
    }


    /*
    * @dev Returns the price of token according to the token ratio in the pool. 
    *
    * @param _token Address of token which price should be returned.
    * @return The price of token.
    */
    function getPrice(bool choiceETH) external view returns (uint256) {
        // here is used an extra multipier (10^9) in order to preserve
        // the numerical precision in computations
        return
            choiceETH
                ? (balanceToken * 10**9) / balanceETH
                : (balanceETH * 10**9) / balanceToken;
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
        require(amountLPTokens > 0, "AMMPairETH: invalid amount");
        require(_from != address(0), "AMMPairETH: transfer from zero address");
        require(_to != address(0), "AMMPairETH: transfer to zero address");

        IERC20(address(this)).transferFrom(_from, _to, amountLPTokens);
        return true;
    }
}

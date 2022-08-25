// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IAMMPairETH {
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
        external
        payable
        returns (
            uint256 amountTokenIn,
            uint256 amountETHIn,
            uint256 LPTokensMinted
        );

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
        external
        returns (uint256 amountTokenOut, uint256 amountETHOut);


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
        external
        payable
        returns (uint256 amountTokenOut);

    /*
    * @dev Swaps amount of token for the corresponding amount of ETH.
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
    ) external returns (uint256 amountETHOut);


    /*
    * @dev Returns the price of token or ETH based on the pool ratio. 
    *
    * @param choiceETH The bool value which sets if ETH is chosen for fee payments. 
    * @return The price of token or ETH.
    */
    function getPrice(bool choiceETH) external view returns (uint256);


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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IAMMPairETH {
    function addLiquidity(uint256 amountTokenAdd, address _account)
        external 
        payable 
        returns(
            uint256 amountTokenIn, 
            uint256 amountETHIn,
            uint256 LPTokensMinted
        );

    function removeLiquidity(uint256 LPTokensBurn, address _account) 
        external
        returns(
            uint256 amountTokenOut,
            uint256 amountETHOut
        );

    function swapETHForToken(bool choiceETHFee, address _account) 
        external
        payable
        returns(uint256 amountTokenOut);

    function swapTokenForETH(
        uint256 amount, 
        bool choiceETHFee, 
        address _account
    ) 
        external
        returns(uint256 amountETHOut);
    
    function getPrice(bool choiceETH) external view returns(uint);

    function sendLiquidity(
        uint256 amountLPTokens, 
        address _from, 
        address _to
    )   external
        returns(bool);
}
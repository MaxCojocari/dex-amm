// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IAMMFactoryETH {
    /* 
    * @dev Adds a new pair ETH - ERC20 token. It reverts if
    * pair already exists, even though the tokens are swaped.
    *
    * @param _token The address of token's contract.
    *
    * @return The address of the pool contract.
    */
    function addPair(address _token) external returns (address pair);


    /*
    * @dev Returns the address of the pool contract for specific pair ETH - token.
    * Zero address is returned if pool doesn't exist.
    *
    * @param _token The address of token's contract.
    *
    * @return The address of the pool contract.
    */
    function getAddressPair(address _token) external view returns (address);

    /*
    * @dev This emits if a new pool is created. 
    */
    event AddPair(address indexed token, address pair);
}

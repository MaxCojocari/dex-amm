// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAMMFactory {
    /* 
    * @dev Adds a new pair of two distinct ERC20 tokens. It reverts if
    * pair already exists, even though the tokens are swaped.
    *
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    *
    * @return The address of the pool contract for that pair of tokens.
    */
    function addPair(address _token0, address _token1)
        external
        returns (address);


    /*
    * @dev Returns the address of the pool contract for specific pair of tokens.
    * Zero address is returned if pool doesn't exist.
    *
    * @param _token0 The address of the first token.
    * @param _token1 The address of the second token.
    *
    * @return The address of the pool.
    */
    function getAddressPair(address _token0, address _token1)
        external
        view
        returns (address);


    /*
    * @dev This emits if a new pool is created. 
    */
    event AddPair(address indexed token0, address indexed token1, address pair);
}

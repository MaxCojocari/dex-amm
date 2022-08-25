// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IAMMFactory.sol";
import "./AMMPair.sol";

contract AMMFactory is IAMMFactory {

    // token0 (token1) => token1 (token0) => pool's address
    mapping(address => mapping(address => address)) public pairs;

    modifier properAddresses(address _token0, address _token1) {
        require(
            _token0 != address(0) && _token1 != address(0),
            "AMMFactory: zero address"
        );
        require(_token0 != _token1, "AMMFactory: identical tokens");
        _;
    }


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
        public
        properAddresses(_token0, _token1)
        returns (address pair)
    {
        require(
            pairs[_token0][_token1] == address(0) && pairs[_token1][_token0] == address(0),
            "AMMFactory: pair already exists"
        );

        pair = address(new AMMPair(_token0, _token1));
        pairs[_token0][_token1] = pair;
        pairs[_token1][_token0] = pair;

        emit AddPair(_token0, _token1, pair);
    }


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
        public
        view
        properAddresses(_token0, _token1)
        returns (address)
    {
        return pairs[_token0][_token1];
    }
}

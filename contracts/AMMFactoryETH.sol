// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./interfaces/IAMMFactoryETH.sol";
import "./AMMPairETH.sol";

contract AMMFactoryETH is IAMMFactoryETH {
    
    // token => pool's address
    mapping(address => address) public pairs;

    /* 
    * @dev Adds a new pair ETH - ERC20 token. It reverts if
    * pair already exists, even though the tokens are swaped.
    *
    * @param _token The address of token's contract.
    *
    * @return The address of the pool contract.
    */
    function addPair(address _token) public returns (address pair) {
        require(_token != address(0), "AMMFactoryETH: zero address");
        require(
            pairs[_token] == address(0),
            "AMMFactoryETH: pair already exists"
        );

        pair = address(new AMMPairETH(_token));
        pairs[_token] = pair;

        emit AddPair(_token, pair);
    }


    /*
    * @dev Returns the address of the pool contract for specific pair ETH - token.
    * Zero address is returned if pool doesn't exist.
    *
    * @param _token The address of token's contract.
    *
    * @return The address of the pool contract.
    */
    function getAddressPair(address _token) external view returns (address) {
        return pairs[_token];
    }
}

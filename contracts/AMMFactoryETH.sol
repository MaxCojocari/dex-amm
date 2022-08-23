// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./interfaces/IAMMFactoryETH.sol";
import "./AMMPairETH.sol";

contract AMMFactoryETH is IAMMFactoryETH {
    mapping(address => address) public pairs;

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

    function getAddressPair(address _token) external view returns (address) {
        return pairs[_token];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IAMMFactory.sol";
import "./AMMPair.sol";

contract AMMFactory is IAMMFactory {
    mapping(address => mapping(address => address)) public pairs;

    modifier properAddresses(address _token0, address _token1) {
        require(
            _token0 != address(0) && _token1 != address(0),
            "AMMFactory: zero address"
        );
        require(_token0 != _token1, "AMMFactory: identical tokens");
        _;
    }

    function addPair(address _token0, address _token1)
        public
        properAddresses(_token0, _token1)
        returns (address pair)
    {
        require(
            pairs[_token0][_token1] == address(0) &&
                pairs[_token1][_token0] == address(0),
            "AMMFactory: pair already exists"
        );

        pair = address(new AMMPair(_token0, _token1));
        pairs[_token0][_token1] = pair;
        pairs[_token1][_token0] = pair;

        emit AddPair(_token0, _token1, pair);
    }

    function getAddressPair(address _token0, address _token1)
        public
        view
        properAddresses(_token0, _token1)
        returns (address)
    {
        return pairs[_token0][_token1];
    }
}

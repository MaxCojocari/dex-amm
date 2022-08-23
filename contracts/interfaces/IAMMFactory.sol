// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAMMFactory {
    function addPair(address _token0, address _token1)
        external
        returns (address);

    function getAddressPair(address _token0, address _token1)
        external
        view
        returns (address);

    event AddPair(address indexed token0, address indexed token1, address pair);
}

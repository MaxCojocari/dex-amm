// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IAMMFactoryETH {
    function addPair(address _token) external returns (address pair);

    function getAddressPair(address _token) external view returns (address);

    event AddPair(address indexed token, address pair);
}

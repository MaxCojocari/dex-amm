// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library AMMMath {
    function min(uint256 a, uint256 b) external pure returns(uint256) {
        return a > b ? b : a;
    }

    function sqrt(uint y) external pure returns (uint z) {
        if (y == 0) {
            z = 0;
        } else if (y <= 3) {
            z = 1;
        } else {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        }
    }
}
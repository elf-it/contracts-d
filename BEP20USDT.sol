// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./lib/BEP20.sol";

contract BEP20USDT is BEP20 {

    constructor(uint256 supply) BEP20("Tether USD","USDT", 18) {
        _mint(msg.sender, supply);
    }

    function mint() external{
        _mint(msg.sender, 100000*1e18);
    }
    
}

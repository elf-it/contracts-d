// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./lib/BEP20.sol";
import "./lib/ECDSA.sol";
import "./lib/SafeMath.sol";
import "./lib/IPancakeRouter02.sol";
import "./lib/TransferHelper.sol";

contract PancakeERC20 is BEP20 {

    constructor(uint256 supply) BEP20("Pancake LPs","Cake-LP", 18) {
        _mint(msg.sender, supply);
    }

    function mint() external{
        _mint(msg.sender, 1000*1e18);
    }
    
}

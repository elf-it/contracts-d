// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./lib/BEP20.sol";
import "./lib/ECDSA.sol";
import "./lib/SafeMath.sol";
import "./lib/IPancakeRouter02.sol";
import "./lib/TransferHelper.sol";

contract MockBEP20 is BEP20 {

    constructor(string memory name,string memory symbol,uint256 supply) BEP20(name, symbol, 18) {
        _mint(msg.sender, supply);
    }

    function mint() external{
        _mint(msg.sender, 1000*1e18);
    }
    
}

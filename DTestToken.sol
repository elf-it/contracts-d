// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./lib/BEP20.sol";
import "./lib/ECDSA.sol";
import "./lib/SafeMath.sol";
import "./lib/IPancakeRouter02.sol";
import "./lib/TransferHelper.sol";

contract DTestToken is BEP20 {
    using SafeMath for uint256;
    using TransferHelper for IBEP20;
    address public constant PancakeRouter =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    event Burned(uint256 burnAmount);

    constructor(uint256 supply) BEP20("DTestToken", "DTT", 18) {
        _mint(msg.sender, supply);
    }
//addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)
/*0	tokenA	address	55d398326f99059ff775485246999027b3197955
1	tokenB	address	75c9a145c1a6cb07d2d4df885e016838ca4eacfd
2	amountADesired	uint256	1000000000000000000
3	amountBDesired	uint256	1000000000000000000000000
4	amountAMin	uint256	1000000000000000000
5	amountBMin	uint256	1000000000000000000000000
6	to	address	909e3b28e44cfbb385333b25a9ec5195717c5f1a
7	deadline	uint256	1620169253
*/
    function burn(address bonusToken) external onlyOwner {
        uint256 amount = IBEP20(bonusToken).balanceOf(address(this));
        if (amount > 0) {
            IBEP20(bonusToken).safeIncreaseAllowance(PancakeRouter, amount);
            address[] memory tokenPath = new address[](2);
            tokenPath[0] = bonusToken;
            tokenPath[1] = address(this);

            IPancakeRouter02(PancakeRouter)
                .swapExactTokensForTokens(
                amount,
                0,
                tokenPath,
                address(this),
                block.timestamp + 60
            );
            uint256 burned = balanceOf(address(this));
            if(burned>0){
                _burn(address(this), burned);
                emit Burned(burned);
            }
        }
    }
}

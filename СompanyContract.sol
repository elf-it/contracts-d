// SPDX-License-Identifier: MIT
/*
https://dars.one/
*/
pragma solidity 0.7.6;
import "./lib/IBEP20.sol";
import "./lib/TransferHelper.sol";
import "./lib/Ownable.sol";

contract CompanyContract is Ownable{

    using TransferHelper for IBEP20;

    event Withdraw(address user, uint256 amount);

    IBEP20 immutable public paymentToken;


    constructor(address _paymentToken){
        paymentToken=IBEP20(_paymentToken);
    }

    function withdrawTo(address user,uint256 amount) external onlyOwner {
        require(user!=address(0),"cant withdraw to zero address");
        require(amount>0 && paymentToken.balanceOf(address(this))>=amount,"bad amount");
        paymentToken.safeTransfer(user, amount);
        emit Withdraw(user, amount);
    }
}
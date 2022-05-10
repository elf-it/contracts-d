// SPDX-License-Identifier: MIT
/*
https://dars.one/
*/
pragma solidity 0.7.6;
import "./lib/IBEP20.sol";
import "./lib/SafeMath.sol";
import "./lib/TransferHelper.sol";
import "./BonusContract.sol";
import "./lib/Ownable.sol";



contract BonusContractEx is Ownable{

    using SafeMath for uint256;
    using TransferHelper for IBEP20;

    BonusContract public bonusContract;
    IBEP20 public bonusToken;
    address public darsBasis;
    uint256 public darsPercent;

    event BuyEx(address user,uint256 price,bytes32 orderUID);

    constructor(address _bonusContractAddress,address _manufacturer) {
        bonusContract=BonusContract(_bonusContractAddress);
        bonusToken=bonusContract.bonusToken();
        darsBasis=bonusContract.darsBasis();
        darsPercent=bonusContract.darsPercent();
        require(address(bonusToken)!=address(0) 
                && darsBasis!=address(0) 
                && darsPercent>0,"wrong bonusContractAddress");
        _transferOwnership(_manufacturer);
    }

    function withdrawBonusToken() external onlyOwner{
        bonusToken.safeTransfer(msg.sender, bonusToken.balanceOf(address(this)));
    }

    function buyEx(uint256 price,uint256 amountToBonusContract,
                uint256 marketing,bytes32 orderUID) external {
        
        require(price>0 && amountToBonusContract>0,"price and amountToBonusContract must be greater than zero");
        require(
            bonusToken.allowance(msg.sender, address(this)) >=
                price,
            "Increase the allowance first,call the approve method"
        );
        
        bonusToken.safeTransferFrom(
            msg.sender,
            address(this),
            price
        );

        uint256 remain=price.sub(amountToBonusContract,"amountToBonusContract too much");
        if(remain>0){
            uint256 toDarsAmount=remain.mul(darsPercent).div(100);
            bonusToken.safeTransfer(darsBasis, toDarsAmount);
        }       

        if(amountToBonusContract>0){
            bonusToken.safeIncreaseAllowance(address(bonusContract), amountToBonusContract);
            bonusContract.buyOutside(msg.sender,amountToBonusContract,marketing);
        }

        emit BuyEx(msg.sender,price,orderUID);
    }

}
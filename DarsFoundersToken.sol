// SPDX-License-Identifier: MIT
/*
https://dars.one/
*/
pragma solidity 0.7.6;

import "./lib/BEP20.sol";
import "./lib/IBEP20.sol";
import "./lib/TransferHelper.sol";

pragma experimental ABIEncoderV2;

contract DarsFoundersToken is BEP20 {
    using SafeMath for uint256;
    using TransferHelper for IBEP20;

    struct Founders{
        address user;
        uint256 share;
    }

    IBEP20 public rewardToken;
    uint256 constant public minInReward=1e18;
    uint256 constant public MaxSupply=100*1e18;
    uint256 public lastFixedBalance;
    uint256 public totalDividends;
    mapping(address=>uint256) initialBalance;
    uint256 public currentRewardPerShare;

    event Dividends(address user, uint256 amount);

    constructor(address _rewardToken,Founders[] memory _founders) 
        BEP20("DARS Founders Token","DFT", 18) {

        rewardToken=IBEP20(_rewardToken);
        uint256 shareSUMM=0;

        for (uint256 i = 0; i < _founders.length; i++) {
            require(_founders[i].share>0 && _founders[i].share<=MaxSupply,"bad founder share");
            shareSUMM=shareSUMM.add(_founders[i].share);
            _mint(_founders[i].user, _founders[i].share);
        }
        require(shareSUMM==MaxSupply,"_holders share summ is wrong");
        
    }

    function distributeDividends() public {
        uint256 rBalance=rewardToken.balanceOf(address(this));
        uint256 amount=rBalance.sub(lastFixedBalance);
        if(amount>minInReward){
            lastFixedBalance=rBalance;
            currentRewardPerShare=currentRewardPerShare.add(amount.mul(1e12).div(MaxSupply));

        }    
    }

    function _dividendsTransfer(address _to, uint256 _amount) internal {
        uint256 max=rewardToken.balanceOf(address(this));
        if (_amount > max) {
            _amount=max;
        }

        initialBalance[_to] = balanceOf(_to)
        .mul(currentRewardPerShare)
        .div(1e12);

        lastFixedBalance=lastFixedBalance.sub(_amount);
        totalDividends=totalDividends.add(_amount);

        rewardToken.safeTransfer(_to, _amount);
        emit Dividends(_to, _amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        distributeDividends();
        if(from!=address(0)){
            uint256 dividends = calculateDividends(from);
            if (dividends > 0) {
                _dividendsTransfer(from, dividends);
            }
            initialBalance[from] = balanceOf(from).sub(amount,
                "BEP20: transfer amount exceeds balance").mul(currentRewardPerShare).div(1e12);
        }

        if(balanceOf(to) > 0) {
            uint256 dividends = calculateDividends(to);
            if (dividends > 0) {
                _dividendsTransfer(to, dividends);
            }
        }

        initialBalance[to] = balanceOf(to).add(amount).mul(currentRewardPerShare).div(1e12);
    }

    function withdrawDividends() external {
        distributeDividends();
        require(
            balanceOf(msg.sender) > 0,
            "you do not have founders tokens"
        );
        uint256 dividends = calculateDividends(msg.sender);
        if (dividends > 0) {
            _dividendsTransfer(msg.sender, dividends);
        }
    }

    function calculateDividends(address userAddress)
        public
        view
        returns (uint256)
    {
        return balanceOf(userAddress)
        .mul(currentRewardPerShare)
        .div(1e12)
        .sub(initialBalance[userAddress]);
    }   
    
}
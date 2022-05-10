// SPDX-License-Identifier: MIT
/*
https://dars.one/
*/
pragma solidity 0.7.6;

import "./lib/IBEP20.sol";
import "./lib/SafeMath.sol";
import "./lib/TransferHelper.sol";
import './lib/IPancakePair.sol';

pragma experimental ABIEncoderV2;

contract DarsStake {
    using SafeMath for uint256;
    using TransferHelper for IBEP20;

    IBEP20 immutable public rewardToken;
    IBEP20 immutable public lpDarsToken;
    IPancakePair immutable public pancakePair;
    

    struct UserInfo {
        uint256 depositTimestamp;
        uint256 sharesAmount;
        uint256 initialDepositAmount;
        uint256 dividendsAmount;
    }

    struct PoolInfo {
        uint256 currentRewardPerShare;
        uint256 sharesTotal;
        uint256 usersInStake;
        uint256 freezingPeriod;
        uint256 totalDividends;
    }

    PoolInfo public poolInfo;
    mapping(address => UserInfo) public usersInfo;

    

    event Stake(address user, uint256 amount);
    event PoolCharged(uint256 amount);
    event UnStake(address user, uint256 amount);
    event Dividends(address user, uint256 amount);

    constructor(
        address _lpDarsToken,
        address _rewardToken,
        uint256 _freezingPeriod
    ) {
        pancakePair=IPancakePair(_lpDarsToken);
        lpDarsToken = IBEP20(_lpDarsToken);
        rewardToken=IBEP20(_rewardToken);
        poolInfo=PoolInfo({
            currentRewardPerShare:0,
            sharesTotal:0,
            usersInStake:0,
            freezingPeriod:_freezingPeriod,
            totalDividends:0
        });  
    }

    function getDarsRate() public view returns (uint256) {
        
        (uint112 reserves0, uint112 reserves1,) = pancakePair.getReserves();
        (uint112 reserveIn, uint112 reserveOut) = pancakePair.token0() == address(rewardToken) ? (reserves0, reserves1) : (reserves1, reserves0);
        
        if (reserveIn > 0 && reserveOut > 0 && 1e18 < reserveOut){
            uint256 numerator = uint256(1e18).mul(10000).mul(reserveIn);
            uint256 denominator = uint256(reserveOut).sub(1e18).mul(9975);
            return numerator.div(denominator).add(1);
        }else{
            return 0;
        }

    }

    function chargePool(uint256 value) external {

        rewardToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            value
        );

        if (poolInfo.usersInStake > 0) {
            poolInfo.currentRewardPerShare=poolInfo.currentRewardPerShare.add(value.mul(1e12).div(poolInfo.sharesTotal));
            emit PoolCharged(value);
        }
    }

    function dividendsTransfer(address _to, uint256 _amount) internal {
        uint256 max=rewardToken.balanceOf(address(this));
        if (_amount > max) {
            _amount=max;
        }

        usersInfo[_to].initialDepositAmount = usersInfo[_to].sharesAmount
        .mul(poolInfo.currentRewardPerShare)
        .div(1e12);

        usersInfo[_to].dividendsAmount=usersInfo[_to].dividendsAmount.add(_amount);
        poolInfo.totalDividends=poolInfo.totalDividends.add(_amount);

        rewardToken.safeTransfer(_to, _amount);
        emit Dividends(_to, _amount);
    }

    function stake(uint256 _amount) external {

        require(_amount > 0, "amount must be greater than 0");
        
        require(
            lpDarsToken.allowance(address(msg.sender), address(this)) >=
                _amount,
            "Increase the allowance first,call the approve method"
        );

        UserInfo storage user = usersInfo[msg.sender];

        if (user.sharesAmount > 0) {
            uint256 dividends = calculateDividends(msg.sender);
            if (dividends > 0) {
                dividendsTransfer(msg.sender, dividends);
            }
        }else{
            poolInfo.usersInStake++;
        }
        
        lpDarsToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        user.depositTimestamp = block.timestamp;
        user.sharesAmount = user.sharesAmount.add(_amount);
        user.initialDepositAmount = user.sharesAmount.mul(poolInfo.currentRewardPerShare).div(1e12);
        poolInfo.sharesTotal = poolInfo.sharesTotal.add(_amount);
        emit Stake(msg.sender, _amount);

        if (poolInfo.usersInStake == 1 && user.sharesAmount== _amount ) {
            uint256 balance=rewardToken.balanceOf(address(this));
            if(balance>0){
                poolInfo.currentRewardPerShare = poolInfo.currentRewardPerShare.add(balance.mul(1e12).div(poolInfo.sharesTotal));
                emit PoolCharged(balance);
            }                 
        } 
      
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() external {

        UserInfo storage user = usersInfo[msg.sender];
        uint256 unstaked_shares = user.sharesAmount;
        require(
            unstaked_shares > 0,
            "you do not have staked tokens, stake first"
        );
        require(isTokensFrozen(msg.sender) == false, "tokens are frozen");
        user.sharesAmount = 0;
        user.initialDepositAmount = 0;
        poolInfo.sharesTotal = poolInfo.sharesTotal.sub(unstaked_shares);
        poolInfo.usersInStake--; 
        lpDarsToken.safeTransfer(msg.sender, unstaked_shares);
        emit UnStake(msg.sender, unstaked_shares);
    }

    function unstake(uint256 _amount) external {
        UserInfo storage user = usersInfo[msg.sender];

        require(
            _amount > 0 && _amount<=user.sharesAmount,"bad _amount"
        );
        require(isTokensFrozen(msg.sender) == false, "tokens are frozen");

        uint256 dividends = calculateDividends(msg.sender);
        if (dividends > 0) {
            dividendsTransfer(msg.sender, dividends);
        }
        user.sharesAmount=user.sharesAmount.sub(_amount);
        user.initialDepositAmount = user.sharesAmount.mul(poolInfo.currentRewardPerShare).div(1e12);
        poolInfo.sharesTotal = poolInfo.sharesTotal.sub(_amount);
        if(user.sharesAmount==0){poolInfo.usersInStake--;}
        
        lpDarsToken.safeTransfer(msg.sender, _amount);

        emit UnStake(msg.sender, _amount);
    }

    function getDividends() external {
        require(
            usersInfo[msg.sender].sharesAmount > 0,
            "you do not have staked tokens, stake first"
        );
        uint256 dividends = calculateDividends(msg.sender);
        if (dividends > 0) {
            dividendsTransfer(msg.sender, dividends);
        }
    }

    function calculateDividends(address userAddress)
        public
        view
        returns (uint256)
    {
        return usersInfo[userAddress].sharesAmount
        .mul(poolInfo.currentRewardPerShare)
        .div(1e12)
        .sub(usersInfo[userAddress].initialDepositAmount);
    }

    function isTokensFrozen(address userAddress) public view returns (bool) {
        return (poolInfo.freezingPeriod >(block.timestamp.sub(usersInfo[userAddress].depositTimestamp)));
    }

    function getPool()
        external
        view
        returns (PoolInfo memory)
    {
        return poolInfo;
    }

    function getUser(address userAddress)
        external
        view
        returns (UserInfo memory)
    {
        return usersInfo[userAddress];
    }

}

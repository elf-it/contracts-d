// SPDX-License-Identifier: MIT
/*
https://dars.one/
*/
pragma solidity 0.7.6;
import "./lib/IBEP20.sol";
import "./lib/SafeMath.sol";
import "./lib/TransferHelper.sol";

pragma experimental ABIEncoderV2;

contract DarsReserve {
    using SafeMath for uint256;
    using TransferHelper for IBEP20;

    struct ADMIN{
        uint256 reserve;
        mapping(uint32=>uint256) spent;
    }

    address public constant dev1=0x6e339A99549e2fF536F972Ef227cF5F22a8A58E5;
    address public constant dev2=0xF4293330eF51997D0FA8dfc6DFE493Dd5048A96b;

    modifier onlyDev() {
        require(dev1 == msg.sender 
                || dev2 == msg.sender,
                 "caller is not a developer");
        _;
    }

    uint256 immutable public startTimestamp;
    mapping(uint32=>uint256) totalSpent;
    IBEP20 public bonusToken;
    uint256 public freeReserve;
    mapping(address=>ADMIN) reserveAdmins;

    constructor(address _bonusToken,uint256 _freeReserve){
        bonusToken=IBEP20(_bonusToken);
        freeReserve=_freeReserve;
        startTimestamp=block.timestamp;
        
    }
    
    event Withdraw(address indexed user, uint256 amount);

    function addAdmin(address admin,uint256 amount) external onlyDev {
        require(amount>0 && amount<=freeReserve,"bad amount");
        require(reserveAdmins[admin].reserve==0,"this admin already added");
        freeReserve=freeReserve.sub(amount);
        reserveAdmins[admin].reserve=amount;
    }
    function moveAdmin(address _admin,address _newadmin) external onlyDev {
        require(reserveAdmins[_admin].reserve>0,"this admin not added yet");
        uint32 period=getCurrentPeriod();
        reserveAdmins[_newadmin].reserve=reserveAdmins[_newadmin].reserve.add(reserveAdmins[_admin].reserve);
        reserveAdmins[_newadmin].spent[period]=reserveAdmins[_newadmin].spent[period].add(reserveAdmins[_admin].spent[period]);
        reserveAdmins[_admin].reserve=0;
        reserveAdmins[_admin].spent[period]=0;  
    }
    function withdraw(uint256 amount) external{
        require(amount>0,"amount must be greater than 0");
        require(reserveAdmins[msg.sender].reserve>0,"not available for this account");
        uint32 period=getCurrentPeriod();
        uint256 cBonusBalance=bonusToken.balanceOf(address(this));
        uint256 availableAmount=reserveAdmins[msg.sender].reserve.sub(reserveAdmins[msg.sender].spent[period]);
        require(amount<=availableAmount && amount<=cBonusBalance,"amount exceeded");
        reserveAdmins[msg.sender].spent[period]=reserveAdmins[msg.sender].spent[period].add(amount);
        totalSpent[period]=totalSpent[period].add(amount);
        bonusToken.safeTransfer(address(msg.sender), amount);
        emit Withdraw(msg.sender,amount);
    }

    function getAvailableAmount(address user) public view returns (uint256) {
        if(reserveAdmins[user].reserve>0){
            uint32 period = getCurrentPeriod();
            return reserveAdmins[user].reserve.sub(reserveAdmins[user].spent[period]);
        }else{
            return 0;
        } 
    }

    function getCurrentPeriod() public view returns (uint32) {
        return uint32(block.timestamp.sub(startTimestamp).div(2592000));//60*60*24*30
    }

    function getTotalSpent(uint32 _period) public view returns (uint256) {
        return totalSpent[_period];
    }

}
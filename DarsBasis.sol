// SPDX-License-Identifier: MIT
/*
https://dars.one/
*/
pragma solidity 0.7.6;
import "./lib/IBEP20.sol";
import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import "./BonusContract.sol";
import "./lib/IPancakeRouter02.sol";
import "./lib/TransferHelper.sol";

pragma experimental ABIEncoderV2;

contract DarsBasis is Ownable {
    
    using SafeMath for uint256;
    using TransferHelper for IBEP20;
    struct CompanyInfo{
        string darsAccount;
        address contractAddress;
        address companyOwner;
        address darsGuardian;
    }   

    address immutable public PancakeRouter;//0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address immutable public bonusToken;//0x55d398326f99059ff775485246999027b3197955  usdt
    address immutable public darsPool;
    address immutable public darsToken;
    address immutable public darsShareholders;
    address immutable public darsReserveAddress;
    uint256 immutable public minDistrBalance;
    uint256 immutable public darsReserveAmount;

    mapping (address => address)  public companies;
    CompanyInfo[] public allCompanies;
    uint256 public darsPercent;
    uint256 public burnPercent;
    uint256 public poolPercent;
    address public constant dev1=0x6C8F69523858b9A4124b59876E9ffE9f6B84e2Ce;
    address public constant dev2=0xF4293330eF51997D0FA8dfc6DFE493Dd5048A96b;

    modifier onlyDev() {
        require(dev1 == msg.sender 
                || dev2 == msg.sender 
                || owner() == msg.sender,
                 "caller is not a developer");
        _;
    }

    event CompanyCreated(string darsName, string Url, address companyOwner, address contractAddress);

    constructor (address _pancakeRouter,
                address _bonusToken,
                address _darsPool,
                address _darsToken,
                address _darsShareholders,
                address _darsReserveAddress,
                uint256 _darsReserveAmount) {
        PancakeRouter=_pancakeRouter;
        bonusToken = _bonusToken;
        darsPool = _darsPool;
        darsToken = _darsToken;
        darsShareholders = _darsShareholders;
        darsReserveAddress=_darsReserveAddress;
        darsReserveAmount=_darsReserveAmount; 
        darsPercent=50;
        burnPercent=25;
        poolPercent=25;
        minDistrBalance=10*10**IBEP20(_bonusToken).decimals();
    }
    
    //percentages without floating part is enough
    function setDistributionPercents(uint256 _darsPercent,uint256 _burnPercent,uint256 _poolPercent) external onlyOwner {
        require(_darsPercent.add(_burnPercent.add(_poolPercent))==100,"bad percent");
        darsPercent =_darsPercent;
        burnPercent =_burnPercent;
        poolPercent =_poolPercent;
    }
    function createCompany(address _companyOwner,
                            address _companySigner,
                            address _darsGuardian,
                            address _companyContract,
                            uint256 _darsPercent,
                            uint256 _bonusPercent,
                            string memory _darsName,
                            string memory _Url) external onlyDev {

        require(!isCompanyExists(_companyOwner), "companyOwner is already exists");

        bytes memory bytecode = type(BonusContract).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(_companyOwner, _companySigner, _darsGuardian, _companyContract,bonusToken,_darsPercent, _bonusPercent,_darsName, _Url));
        bytes32 salt = keccak256(abi.encodePacked( _darsName, _companyOwner, _darsGuardian));

        address contractAddress;
        assembly {
            contractAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(contractAddress != address(0), "Create2: Failed on deploy");
        
        companies[_companyOwner] = contractAddress;
        allCompanies.push(CompanyInfo({
                                    darsAccount:_darsName,
                                    contractAddress:contractAddress,
                                    companyOwner:_companyOwner,
                                    darsGuardian:_darsGuardian}));
        
        emit CompanyCreated(_darsName, _Url, _companyOwner, contractAddress);
        
    }

    function distribute() external{
        
        uint256 cBalance=IBEP20(bonusToken).balanceOf(address(this));
        require(cBalance>=minDistrBalance,"balance should be greater");

        uint256 toDarsAmount=cBalance.mul(darsPercent).div(100);
        uint256 toPoolAmount=cBalance.mul(poolPercent).div(100);
        uint256 toBurnAmount=cBalance.mul(burnPercent).div(100);

        uint256 reserveBalance=IBEP20(bonusToken).balanceOf(darsReserveAddress);

        if(toDarsAmount>0){
            if(reserveBalance<darsReserveAmount){
                IBEP20(bonusToken).safeTransfer(darsReserveAddress, toDarsAmount);
            }else{
                IBEP20(bonusToken).safeTransfer(darsShareholders, toDarsAmount);
            }
        }
        
        if(toPoolAmount>0){
            IBEP20(bonusToken).safeIncreaseAllowance(darsPool, toPoolAmount);
            (bool success,) = darsPool.call(abi.encodeWithSignature("chargePool(uint256)",toPoolAmount));
            require(success,"chargePool FAIL");
        }

        if(toBurnAmount>0){
            IBEP20(bonusToken).safeIncreaseAllowance(PancakeRouter, toBurnAmount);
            address[] memory tokenPath = new address[](2);
            tokenPath[0] = bonusToken;
            tokenPath[1] = darsToken;

            IPancakeRouter02(PancakeRouter)
                .swapExactTokensForTokens(
                toBurnAmount,
                0,
                tokenPath,
                address(this),
                block.timestamp + 60
            );
            uint256 burned = IBEP20(darsToken).balanceOf(address(this));
            if(burned>0){
                (bool success,) = darsToken.call(abi.encodeWithSignature("burn(uint256)",burned));
                require(success,"burn FAIL");
            }
        }

    }

    function isCompanyExists(address companyOwn) public view returns (bool) {
        return (companies[companyOwn]!=address(0));
    }
    function companiesNumber() public view returns (uint256) {
        return allCompanies.length;
    }
    function companiesList() public view returns (CompanyInfo[] memory) {
        return allCompanies;
    }

}
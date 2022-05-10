// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./lib/BEP20.sol";
import "./lib/SafeMath.sol";

contract CompanyToken is BEP20("Company Token","TEST", 18) {
    using SafeMath for uint256;


    address public darsContract;

    modifier onlyDars() {
        require(msg.sender == darsContract, 
                "CompanyToken: not allowed");
        _;
    }

    function setDarsContract(address _darsContract) external onlyOwner{
        require(darsContract==address(0),"CompanyToken: darsContract already set");
        darsContract = _darsContract;
    }

    function delivery(address user,
                    uint256 packetType,
                    uint256 quantity,
                    uint256 packageId,
                    uint256 amount) external onlyDars { 
        _delivery(user, packetType, quantity, packageId, amount);
    }

    function upgradeDelivery(address user,
                    uint256 packetType,
                    uint256 quantity,
                    uint256 packageId,
                    uint256 amount) external onlyDars{ 
        _delivery(user, packetType, quantity, packageId, amount);
    }

    function _delivery(address user,
                    uint256 packetType,
                    uint256 quantity,
                    uint256 packageId,
                    uint256 amount) private {
        
        _mint(user, amount);

    }
}

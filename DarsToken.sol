// SPDX-License-Identifier: MIT
/*
https://dars.one/
*/
pragma solidity 0.7.6;

import "./lib/BEP20.sol";
import "./lib/ECDSA.sol";
import "./lib/SafeMath.sol";

contract DarsToken is BEP20 {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    uint256 public constant SWAPPING_LIMIT = 785849035 * 1e18;
    uint256 public totalSwapped;
    address public darsSwapSigner;
    mapping(address => uint256) public users;
    

    event Burned(uint256 burnAmount);

    constructor(address _darsSwapSigner) BEP20("DarsToken", "DRS", 18) {
        require(_darsSwapSigner!=address(0),"darsSwapSigner cannot be zero address");
        darsSwapSigner = _darsSwapSigner;
    }

    function setDarsSwapSigner(address _darsSwapSigner) external onlyOwner {
        darsSwapSigner = _darsSwapSigner;
    }

    function swap(uint256 amount, bytes memory signatureDars) external {
        require(users[msg.sender]==uint256(0), "already swaped");
        require(amount>0, "amount must be greater than 0");      
        bytes32 hash = keccak256(abi.encodePacked(this, msg.sender, amount));
        hash = hash.toEthSignedMessageHash();
        require(hash.recover(signatureDars) == darsSwapSigner,"signature is wrong");
        users[msg.sender] = amount;
        totalSwapped=totalSwapped.add(amount);
        _mint(msg.sender, amount);
        require(
            totalSwapped <= SWAPPING_LIMIT,
            "total swapped exceeded"
        );
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Burned(amount);
    }

}

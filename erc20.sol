// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

contract EpisodeCoin is ERC20, Ownable {
    
    constructor(uint256 initialSupply) ERC20("EpisodeCoin", "EPIS") {
        _mint(msg.sender, initialSupply);
    }
    
}
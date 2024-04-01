// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAI is ERC20{
    constructor(uint256 initialSupply, address to) ERC20("DAI","DAI"){
        _mint(to,initialSupply);
        _mint(msg.sender,initialSupply);
    }
}

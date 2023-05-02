// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    uint8 tokenDecimals;
    constructor(string memory name, string memory symbol, uint8 _decimals,  uint initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        tokenDecimals = _decimals;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }
}
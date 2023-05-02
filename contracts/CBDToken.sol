// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CBDToken is ERC20, ERC20Burnable {



    mapping(address => bool) public distributors; //is given address distributor 
    mapping(address => bool) public owners; //is given address owner 

    /**
    @param _name : token name
    @param _symbol : token symbol
     */
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        owners[msg.sender] = true;
    }


    function isOwner(address _user) public view returns(bool){
        return owners[_user];
    } 
    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwners() {
        _checkOwners();
        _;
    }


    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwnerOrDistributor() {
        _checkOwnerOrDistributor();
        _;
    }
    
    // Check msg.sender should be owner
    function _checkOwners() internal view virtual {
        require(owners[_msgSender()], "Ownable_Distributor: caller is not from the owners");
    }

    // Check msg.sender should be owner or ditributor
    function _checkOwnerOrDistributor() internal view virtual {
        require(owners[_msgSender()] || distributors[_msgSender()], "Ownable_Distributor: caller is not the owner or distributor");
    }


    function transferUserOwnership(address _newOwner) public onlyOwners{
        owners[_msgSender()] = false;
        owners[_newOwner] = true;
    }

    function addOwner(address _newOwner) public onlyOwners{
        owners[_newOwner] = true;
    }

    function removeOwner(address _newOwner) public onlyOwners{
        owners[_newOwner] = false;
    }

    
    /**
    @param _distributor is a contract or wallet address that can mint or burn tokens
     */
    function addDistributor(address _distributor) external onlyOwners {
    distributors[_distributor] = true;
    }

    function removeDistributor(address _distributor) external onlyOwners {
    distributors[_distributor] = false;
    }


    //mint tokens by owner or distributor
    function mint(address to, uint256 amount) public onlyOwnerOrDistributor {
        _mint(to, amount);
    }

    function burn(address account, uint amount) public onlyOwnerOrDistributor {
        _burn(account, amount);
    }


}
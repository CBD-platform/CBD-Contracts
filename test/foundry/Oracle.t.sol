// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/CBDToken.sol";
import "../../contracts/Purchase.sol";
import "../../contracts/test/Token.sol";
import "../../contracts/test/MockV3Aggregator.sol";

contract CBDTokenTest is Test {
    CBDToken public cbdToken;
    Token public usdc;
    Token public link;
    MockV3Aggregator public oracle;

    event log_array(Purchase.UserRewards[] val);

    struct UserRewards {
        uint rewardAmount;
        uint endTime;
        uint lastUpdateTime;
    }

    address add1 = vm.addr(1);
    address add2 = vm.addr(2);
    address add3 = vm.addr(3);
    address add4 = vm.addr(4);
    address add5 = vm.addr(5);
    address add6 = vm.addr(6);

    

    function setUp() public {
        link = new Token(
            "Link Token",
            "LINK",
            18,
            1000000e18
        );
        
        oracle = new MockV3Aggregator(
            18,
            1
        );
        
    }

    function testPrice() public {
        (,int price,,,) = oracle.latestRoundData();
        assertEq(price, 1);
        oracle.updateAnswer(3);
        (,price,,,) = oracle.latestRoundData();
        assertEq(price, 3);
    }
}

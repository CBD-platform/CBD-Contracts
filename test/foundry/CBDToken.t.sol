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
    Purchase public purchaseContract;
    Token public link;
    MockV3Aggregator public oracle;

    event log_array(Purchase.UserRewards[] val);

    struct UserRewards {
        uint256 rewardAmount;
        uint256 endTime;
        uint256 lastUpdateTime;
    }

    address add1 = vm.addr(1);
    address add2 = vm.addr(2);
    address add3 = vm.addr(3);
    address add4 = vm.addr(4);
    address add5 = vm.addr(5);
    address add6 = vm.addr(6);
    address testReceiver = vm.addr(7);
    address newAdmin = vm.addr(8);

    uint256 reward1 = 95e17;
    uint256 reward2 = 75e17;
    uint256 reward3 = 6e18;
    uint256 reward4 = 4e18;

    function setUp() public {
        usdc = new Token("USD Coin", "USDC", 18, 1000000e18);
        cbdToken = new CBDToken("CBD Token", "CBD");

        oracle = new MockV3Aggregator(18, 1e18);

        purchaseContract = new Purchase(
            address(cbdToken),
            address(usdc),
            20e18,
            address(oracle)
        );
        cbdToken.addDistributor(address(purchaseContract));

        usdc.transfer(add1, 1050e18);
        usdc.transfer(add2, 1050e18);
        usdc.transfer(add3, 1050e18);
        usdc.transfer(add4, 1050e18);
        usdc.transfer(add5, 1050e18);
    }

    function testOraclePrice() public {
        assertEq(purchaseContract.getOracleUsdcPrice(), 1e18);
        oracle.updateAnswer(95e16);
        assertEq(purchaseContract.getOracleUsdcPrice(), 95e16);
    }

    function testPrice() public {
        assertEq(purchaseContract.tokenPrice(), 20e18);
        purchaseContract.setTokenPrice(22e18);
        assertEq(purchaseContract.tokenPrice(), 22e18);
    }

    function testMint() public {
        cbdToken.mint(add1, 1e18);
        assertEq(cbdToken.balanceOf(add1), 1e18);
    }

    function testPurchaseToken() public {
        assertEq(purchaseContract.purchaseToken(), address(usdc));
    }

    function testUsdcPriceExpectReverts() public {
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 1000e18);
        oracle.updateAnswer(94e16);
        vm.expectRevert("USDC price is not above 0.95 $");
        purchaseContract.buyToken(1000e18, address(0));
    }

    function testBuy() public {
        uint initialReward = (1000e18*3*90)/100/20;
        // buy token add1
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 1000e18);
        purchaseContract.buyToken(1000e18, address(0));
        assertEq(cbdToken.balanceOf(add1), 15e18);
        assertEq(usdc.balanceOf(add1), 0);
        vm.stopPrank();
        // buy token add2
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 1000e18);
        purchaseContract.buyToken(1000e18, add1);
        assertEq(cbdToken.balanceOf(add2), 15e18);
        assertEq(usdc.balanceOf(add2), 0);
        assertEq(cbdToken.balanceOf(add1), 20e18);
        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1);
        vm.stopPrank();

        // buy token add3
        vm.startPrank(add3);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 1000e18);
        purchaseContract.buyToken(1000e18, add2);
        assertEq(cbdToken.balanceOf(add3), 15e18);
        assertEq(usdc.balanceOf(add3), 0);
        assertEq(cbdToken.balanceOf(add2), 20e18);
        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1 + reward2);
        assertEq(purchaseContract.allRewardAmounts(add2), initialReward + reward1);
        vm.stopPrank();
        // console.log("time", block.timestamp + 1095 days);
        // buy token add4
        vm.startPrank(add4);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 1000e18);
        purchaseContract.buyToken(1000e18, add3);
        assertEq(cbdToken.balanceOf(add4), 15e18);
        assertEq(usdc.balanceOf(add4), 0);
        assertEq(cbdToken.balanceOf(add3), 20e18);
        assertEq(
            purchaseContract.allRewardAmounts(add1),
            initialReward + reward1 + reward2 + reward3
        );
        assertEq(purchaseContract.allRewardAmounts(add2), initialReward + reward1 + reward2);
        assertEq(purchaseContract.allRewardAmounts(add3), initialReward + reward1);
        vm.stopPrank();

        // buy token add5
        vm.startPrank(add5);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 1000e18);
        purchaseContract.buyToken(1000e18, add4);
        assertEq(cbdToken.balanceOf(add5), 15e18);
        assertEq(usdc.balanceOf(add5), 0);
        assertEq(cbdToken.balanceOf(add4), 20e18);
        assertEq(
            purchaseContract.allRewardAmounts(add1),
            initialReward + reward1 + reward2 + reward3 + reward4
        );
        assertEq(
            purchaseContract.allRewardAmounts(add2),
            initialReward + reward1 + reward2 + reward3
        );
        assertEq(purchaseContract.allRewardAmounts(add3), initialReward + reward1 + reward2);
        assertEq(purchaseContract.allRewardAmounts(add4), initialReward + reward1);
        vm.stopPrank();
        
        // claim rewards
        vm.startPrank(add1);
        uint256 userReward1 = initialReward + reward1 + reward2 + reward3 + reward4;
        assertEq(purchaseContract.allRewardAmounts(add1), userReward1);
        assertEq(purchaseContract.allTotalRewardAmounts(add1), userReward1);
        assertEq(purchaseContract.getUnclaimedRewards(add1), 0);
        uint256 endTime = 1095 days;
        skip(endTime);
        assertEq(purchaseContract.getUnclaimedRewards(add1), userReward1);
        uint add1BalanceBeforeClaimRewards = cbdToken.balanceOf(add1);
        purchaseContract.claimRewards();
        assertEq(purchaseContract.allRewardAmounts(add1), 0);
        assertEq(purchaseContract.getUnclaimedRewards(add1), 0);
        
        assertEq(cbdToken.balanceOf(add1), add1BalanceBeforeClaimRewards + userReward1);
        vm.stopPrank();

        usdc.transfer(add2, 1000e18);
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 1000e18);
        purchaseContract.buyToken(1000e18, add1);

        vm.stopPrank();
        vm.startPrank(add1);
        assertEq(purchaseContract.allRewardAmounts(add1), reward1);
        assertEq(purchaseContract.getUnclaimedRewards(add1), 0);
        uint256 first = block.timestamp;
        uint256 end = block.timestamp + 1095 days;
        uint256 balanceBeforeClaim = cbdToken.balanceOf(add1);
        skip(547 days);
        uint256 unclaimedRewardAmount = (reward1 * (block.timestamp - first)) /
            (end - first);
        assertEq(purchaseContract.allRewardAmounts(add1), reward1);
        assertEq(
            purchaseContract.getUnclaimedRewards(add1),
            unclaimedRewardAmount
        );
        purchaseContract.claimRewards();
        assertEq(
            purchaseContract.allRewardAmounts(add1),
            reward1 - unclaimedRewardAmount
        );
        assertEq(purchaseContract.getUnclaimedRewards(add1), 0);
        assertEq(
            cbdToken.balanceOf(add1),
            balanceBeforeClaim + unclaimedRewardAmount
        );
    }

    
    function testPartailPurchaseRewards() public {
        uint initialReward = (500e18*3*90)/100/20;
        // buy token add1
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 500e18);
        purchaseContract.buyToken(500e18, address(0));
        assertEq(cbdToken.balanceOf(add1), 75e17);
        assertEq(usdc.balanceOf(add1), 500e18);
        vm.stopPrank();
        // buy token add2
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 500e18);
        purchaseContract.buyToken(500e18, add1);
        assertEq(purchaseContract.instantReferRewardHistory(add1), 5e18/2);
        assertEq(cbdToken.balanceOf(add2), 75e17);
        assertEq(usdc.balanceOf(add2), 500e18);
    
        assertEq(cbdToken.balanceOf(add1), 75e17 + 5e18*500e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1*500e18/1000e18);
        vm.stopPrank();
        
        // buy token add3
        vm.startPrank(add3);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 500e18);
        purchaseContract.buyToken(500e18, add2);
        assertEq(purchaseContract.instantReferRewardHistory(add1), 5e18/2);
        assertEq(purchaseContract.instantReferRewardHistory(add2), 5e18/2);
        assertEq(cbdToken.balanceOf(add3), 75e17);
        assertEq(usdc.balanceOf(add3), 500e18);
        assertEq(cbdToken.balanceOf(add2), 75e17 + 5e18*500e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add1),initialReward + reward1*500e18/1000e18 + reward2*500e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add2), initialReward + reward1*500e18/1000e18);
        vm.stopPrank();
        // console.log("time", block.timestamp + 1095 days);
        // buy token add4
        vm.startPrank(add4);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 500e18);
        purchaseContract.buyToken(500e18, add3);
        assertEq(cbdToken.balanceOf(add4), 75e17);
        assertEq(usdc.balanceOf(add4), 500e18);
        assertEq(cbdToken.balanceOf(add3), 75e17 + 5e18*500e18/1000e18);
        assertEq(
            purchaseContract.allRewardAmounts(add1),
            initialReward + reward1*500e18/1000e18 + reward2*500e18/1000e18 + reward3*500e18/1000e18
        );
        assertEq(purchaseContract.allRewardAmounts(add2), initialReward + reward1*500e18/1000e18 + reward2*500e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add3), initialReward + reward1*500e18/1000e18);
        vm.stopPrank();
        // buy token add5
        vm.startPrank(add5);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 500e18);
        purchaseContract.buyToken(500e18, add4);
        assertEq(cbdToken.balanceOf(add5), 75e17);
        assertEq(usdc.balanceOf(add5), 500e18);
        assertEq(cbdToken.balanceOf(add4), 75e17 + 5e18*500e18/1000e18);
        assertEq(
            purchaseContract.allRewardAmounts(add1),
            initialReward + reward1*500e18/1000e18 + reward2*500e18/1000e18 + reward3*500e18/1000e18 + reward4*500e18/1000e18
        );
        assertEq(
            purchaseContract.allRewardAmounts(add2),
            initialReward + reward1*500e18/1000e18 + reward2*500e18/1000e18 + reward3*500e18/1000e18
        );
        assertEq(purchaseContract.allRewardAmounts(add3), initialReward + reward1*500e18/1000e18 + reward2*500e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add4), initialReward + reward1*500e18/1000e18);
        vm.stopPrank();
        // claim rewards
        vm.startPrank(add1);
        uint256 userReward1 = initialReward + reward1*500e18/1000e18 + reward2*500e18/1000e18 + reward3*500e18/1000e18 + reward4*500e18/1000e18;
        assertEq(purchaseContract.allRewardAmounts(add1), userReward1);
        assertEq(purchaseContract.getUnclaimedRewards(add1), 0);
        uint256 endTime = 1095 days;
        skip(endTime);
        assertEq(purchaseContract.getUnclaimedRewards(add1), userReward1);

        purchaseContract.claimRewards();
        assertEq(purchaseContract.allRewardAmounts(add1), 0);
        assertEq(purchaseContract.getUnclaimedRewards(add1), 0);

        vm.stopPrank();
        usdc.transfer(add2, 500e18);
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 500e18);
        purchaseContract.buyToken(500e18, add1);
        vm.stopPrank();

        
        //claim for new rewards
        vm.startPrank(add1);
        uint256 first = block.timestamp;
        uint256 end = block.timestamp + 1095 days;
        uint256 balanceBeforeClaim = cbdToken.balanceOf(add1);
        skip(547 days);
        uint256 unclaimedRewardAmount = (reward1*500e18/1000e18 * (block.timestamp - first)) /
            (end - first);
        assertEq(purchaseContract.allRewardAmounts(add1), reward1*500e18/1000e18);
        assertEq(
            purchaseContract.getUnclaimedRewards(add1),
            unclaimedRewardAmount
        );
        purchaseContract.claimRewards();
        assertEq(
            purchaseContract.allRewardAmounts(add1),
            reward1*500e18/1000e18 - unclaimedRewardAmount
        );
        assertEq(purchaseContract.getUnclaimedRewards(add1), 0);
        assertEq(
            cbdToken.balanceOf(add1),
            balanceBeforeClaim + unclaimedRewardAmount
        );
        
    }

    
    function testPartailPurchaseRewards2() public {
        uint initialReward = (250e18*2*90)/100/20;
        // buy token add1
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 250e18);
        purchaseContract.buyToken(250e18, address(0));
        assertEq(cbdToken.balanceOf(add1), 25e17);
        assertEq(usdc.balanceOf(add1), 750e18);
        vm.stopPrank();
        
        // buy token add2
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 250e18);
        purchaseContract.buyToken(250e18, add1);
        assertEq(purchaseContract.instantReferRewardHistory(add1), 5e18/4);
        assertEq(cbdToken.balanceOf(add2), 25e17);
        assertEq(usdc.balanceOf(add2), 750e18);
        assertEq(cbdToken.balanceOf(add1), 25e17 + 5e18*250e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1*250e18/1000e18);
        assertEq(purchaseContract.allTotalRewardAmounts(add1), initialReward + reward1*250e18/1000e18);
        console.logUint(cbdToken.balanceOf(add1));
        vm.stopPrank();
    }

    function testBuyTokenWithoutRef() public {
        usdc.transfer(add1, 4000e18);
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 5000e18);
        purchaseContract.buyTokenWithoutRef(5000e18);
        assertEq(cbdToken.balanceOf(add1), 250e18);
        assertEq(usdc.balanceOf(add1), 0);
        vm.stopPrank();
    }

    function testRegistered() public {
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 250e18);
        vm.expectRevert("You are not registered");
        purchaseContract.buyToken(250e18, address(0));
    }

    /*
    function consoleRewards(address _user) public view {
        Purchase.UserRewards[] memory rewardS = purchaseContract.userRewards(
            _user
        );
        for (uint256 i; i < rewardS.length; i++) {
            console.log("Reward", i, rewardS[i].rewardAmount);
            console.log("EndTime", i, rewardS[i].endTime);
            console.log("LastUpdate", i, rewardS[i].lastUpdateTime);
            console.log("...........");
        }
        // console.log('..........................................');
    }
    */

    function testTokenOwnership() public {
        assertEq(cbdToken.isOwner(address(this)), true);
        assertEq(cbdToken.isOwner(add1), false);
        cbdToken.addOwner(add1);
        assertEq(cbdToken.isOwner(add1), true);
        vm.startPrank(add1);
        cbdToken.addDistributor(address(usdc));
    }

    function testPurchaseOwnership() public {
        assertEq(purchaseContract.isOwner(address(this)), true);
        assertEq(purchaseContract.isOwner(add1), false);
        purchaseContract.addOwner(add1);
        assertEq(purchaseContract.isOwner(add1), true);
        vm.startPrank(add1);
        purchaseContract.setTokenPrice(30e18);
    }


    function testPurchaseAdmin() public {
        purchaseContract.changeAdmin(newAdmin);
        // buy token add1
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 250e18);
        purchaseContract.buyToken(250e18, address(0));
        assertEq(cbdToken.balanceOf(add1), 25e17);
        assertEq(usdc.balanceOf(add1), 750e18);
        assertEq(usdc.balanceOf(newAdmin), 250e18 + 50e18);
        vm.stopPrank();
    }


    function testPurchaseAdminWithoutRefer() public {
        purchaseContract.changeAdmin(newAdmin);
        usdc.transfer(add1, 4000e18);
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e18);
        purchaseContract.register(50e18, address(0));
        usdc.approve(address(purchaseContract), 5000e18);
        purchaseContract.buyTokenWithoutRef(5000e18);
        assertEq(cbdToken.balanceOf(add1), 250e18);
        assertEq(usdc.balanceOf(add1), 0);
        assertEq(usdc.balanceOf(newAdmin), 5000e18 + 50e18);
        vm.stopPrank();
    }
    
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/CBDToken.sol";
import "../../contracts/Purchase.sol";
import "../../contracts/test/Token.sol";
import "../../contracts/test/MockV3Aggregator.sol";

contract PurchaseTest is Test {
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
        usdc = new Token("USD Coin", "USDC", 6, 1000000e6);
        cbdToken = new CBDToken("CBD Token", "CBD");

        oracle = new MockV3Aggregator(8, 1e8);

        purchaseContract = new Purchase(
            address(cbdToken),
            address(usdc),
            20e6,
            address(oracle)
        );
        cbdToken.addDistributor(address(purchaseContract));

        usdc.transfer(add1, 1050e6);
        usdc.transfer(add2, 1050e6);
        usdc.transfer(add3, 1050e6);
        usdc.transfer(add4, 1050e6);
        usdc.transfer(add5, 1050e6);
    }

    function testOraclePrice() public {
        assertEq(purchaseContract.getOracleUsdcPrice(), 1e18);
        oracle.updateAnswer(95e6);
        assertEq(purchaseContract.getOracleUsdcPrice(), 95e16);
    }

    function testPrice() public {
        assertEq(purchaseContract.tokenPrice(), 20e6);
        purchaseContract.setTokenPrice(22e6);
        assertEq(purchaseContract.tokenPrice(), 22e6);
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
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        oracle.updateAnswer(94e6);
        vm.expectRevert("USDC price is not above 0.95 $");
        purchaseContract.buyToken(1000e6, address(0));
    }
    
    function testBuy() public {
        uint initialReward = (1000e18*3*90)/100/20;
        // buy token add1
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, address(0));
        assertEq(cbdToken.balanceOf(add1), 15e18);
        assertEq(usdc.balanceOf(add1), 0);
        vm.stopPrank();
        // buy token add2
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add1);
        assertEq(cbdToken.balanceOf(add2), 15e18);
        assertEq(usdc.balanceOf(add2), 0);
        assertEq(cbdToken.balanceOf(add1), 20e18);
        //test history
        assertEq(purchaseContract.instantReferRewardHistory(add1), 5e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add1), 95e17);
        assertEq(purchaseContract.allCb2RewardAmounts(add1), 1000e18);

        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1);
        vm.stopPrank();

        // buy token add3
        vm.startPrank(add3);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add2);
        assertEq(cbdToken.balanceOf(add3), 15e18);
        assertEq(usdc.balanceOf(add3), 0);
        assertEq(cbdToken.balanceOf(add2), 20e18);
        //test history
        assertEq(purchaseContract.instantReferRewardHistory(add1), 5e18);
        assertEq(purchaseContract.instantReferRewardHistory(add2), 5e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add1), 95e17 + 75e17);
        assertEq(purchaseContract.dailyReferRewardHistory(add2), 95e17);

        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1 + reward2);
        assertEq(purchaseContract.allRewardAmounts(add2), initialReward + reward1);
        vm.stopPrank();
        // console.log("time", block.timestamp + 1095 days);
        // buy token add4
        vm.startPrank(add4);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add3);
        assertEq(cbdToken.balanceOf(add4), 15e18);
        assertEq(usdc.balanceOf(add4), 0);
        assertEq(cbdToken.balanceOf(add3), 20e18);
        //test history
        assertEq(purchaseContract.instantReferRewardHistory(add1), 5e18);
        assertEq(purchaseContract.instantReferRewardHistory(add2), 5e18);
        assertEq(purchaseContract.instantReferRewardHistory(add3), 5e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add1), 95e17 + 75e17 + 6e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add2), 95e17+ 75e17);
        assertEq(purchaseContract.dailyReferRewardHistory(add3), 95e17);
        assertEq(
            purchaseContract.allRewardAmounts(add1),
            initialReward + reward1 + reward2 + reward3
        );
        assertEq(purchaseContract.allRewardAmounts(add2), initialReward + reward1 + reward2);
        assertEq(purchaseContract.allRewardAmounts(add3), initialReward + reward1);
        vm.stopPrank();

        // buy token add5
        vm.startPrank(add5);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add4);
        assertEq(cbdToken.balanceOf(add5), 15e18);
        assertEq(usdc.balanceOf(add5), 0);
        assertEq(cbdToken.balanceOf(add4), 20e18);
        //test history
        assertEq(purchaseContract.instantReferRewardHistory(add1), 5e18);
        assertEq(purchaseContract.instantReferRewardHistory(add2), 5e18);
        assertEq(purchaseContract.instantReferRewardHistory(add3), 5e18);
        assertEq(purchaseContract.instantReferRewardHistory(add4), 5e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add1), 95e17 + 75e17 + 6e18 + 4e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add2), 95e17 + 75e17 + 6e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add3), 95e17 + 75e17);
        assertEq(purchaseContract.dailyReferRewardHistory(add4), 95e17);
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

        usdc.transfer(add2, 1000e6);
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add1);

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

        //test history
        assertEq(purchaseContract.instantReferRewardHistory(add1), 10e18);
        assertEq(purchaseContract.instantReferRewardHistory(add2), 5e18);
        assertEq(purchaseContract.instantReferRewardHistory(add3), 5e18);
        assertEq(purchaseContract.instantReferRewardHistory(add4), 5e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add1), 95e17 + 95e17 + 75e17 + 6e18 + 4e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add2), 95e17 + 75e17 + 6e18);
        assertEq(purchaseContract.dailyReferRewardHistory(add3), 95e17 + 75e17);
        assertEq(purchaseContract.dailyReferRewardHistory(add4), 95e17);
        assertEq(purchaseContract.boughtMembershipHistory(add1), 1000e6);
        assertEq(purchaseContract.boughtMembershipHistory(add2), 2000e6);
        assertEq(purchaseContract.allCb2RewardAmounts(add2), 2000e18);
    }

    function testCb2Reward() public {
        uint initialReward = (1000e18*3*90)/100/20;
        // buy token add1
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, address(0));
        assertEq(cbdToken.balanceOf(add1), 15e18);
        assertEq(usdc.balanceOf(add1), 0);
        vm.stopPrank();
        //history
        assertEq(purchaseContract.allCb2RewardAmounts(add1), 1000e18);
        assertEq(purchaseContract.getCb2RewardsUntillNow(add1), 0);
        uint256 first = block.timestamp;
        uint256 end = block.timestamp + 1095 days;
        uint256 allCb2 = purchaseContract.allCb2RewardAmounts(add1);
        skip(500 days);
        uint256 unclaimedRewardAmount = (allCb2 * (block.timestamp - first)) /
            (end - first);
        assertEq(purchaseContract.getCb2RewardsUntillNow(add1), unclaimedRewardAmount);
        skip(595 days);
        assertEq(purchaseContract.allCb2RewardAmounts(add1), 1000e18);
        assertEq(purchaseContract.getCb2RewardsUntillNow(add1), 1000e18);
    }

    function testReferedPeople() public{
        uint initialReward = (1000e18*3*90)/100/20;
        // buy token add1
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, address(0));
        assertEq(cbdToken.balanceOf(add1), 15e18);
        assertEq(usdc.balanceOf(add1), 0);
        vm.stopPrank();
        // buy token add2
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add1);
        assertEq(cbdToken.balanceOf(add2), 15e18);
        assertEq(usdc.balanceOf(add2), 0);
        assertEq(cbdToken.balanceOf(add1), 20e18);
        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1);
        vm.stopPrank();

        // buy token add3
        vm.startPrank(add3);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add2);
        assertEq(cbdToken.balanceOf(add3), 15e18);
        assertEq(usdc.balanceOf(add3), 0);
        assertEq(cbdToken.balanceOf(add2), 20e18);
        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1 + reward2);
        assertEq(purchaseContract.allRewardAmounts(add2), initialReward + reward1);
        vm.stopPrank();
        
        // buy token add4
        vm.startPrank(add4);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add3);
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
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add4);
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
        
        // buy token add2 again
        usdc.transfer(add2, 1000e6);
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add3);
        vm.stopPrank();

        // buy token add6
        usdc.transfer(add6, 1050e6);
        vm.startPrank(add6);
         usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 1000e6);
        purchaseContract.buyToken(1000e6, add1);
        vm.stopPrank();

        //test referred people add1
        address[] memory add1People = purchaseContract.userReferredPeople(add1);
        assertEq(add1People[0], add2);
        assertEq(add1People[1], add6);
        assertEq(add1People.length, 2);
        //test referred people add2
        address[] memory add2People = purchaseContract.userReferredPeople(add2);
        assertEq(add2People[0], add3);
        assertEq(add2People.length, 1);
        //test referred people add3
        address[] memory add3People = purchaseContract.userReferredPeople(add3);
        assertEq(add3People[0], add4);
        assertEq(add3People.length, 1);
        //test referred people add4
        address[] memory add4People = purchaseContract.userReferredPeople(add4);
        assertEq(add4People[0], add5);
        assertEq(add4People.length, 1);
        //test referred people add4
        address[] memory add5People = purchaseContract.userReferredPeople(add5);
        // assertEq(add5People[0], address(0));
        assertEq(add5People.length, 0);

    }

    
    function testPartailPurchaseRewards() public {
        uint initialReward = (500e18*3*90)/100/20;
        // buy token add1
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 500e6);
        purchaseContract.buyToken(500e6, address(0));
        assertEq(cbdToken.balanceOf(add1), 75e17);
        assertEq(usdc.balanceOf(add1), 500e6);
        vm.stopPrank();

        // buy token add2
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 500e6);
        purchaseContract.buyToken(500e6, add1);
        assertEq(cbdToken.balanceOf(add2), 75e17);
        assertEq(usdc.balanceOf(add2), 500e6);
    
        assertEq(cbdToken.balanceOf(add1), 75e17 + 5e18*500e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1*500e18/1000e18);
        vm.stopPrank();
        
        // buy token add3
        vm.startPrank(add3);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 500e6);
        purchaseContract.buyToken(500e6, add2);
        assertEq(cbdToken.balanceOf(add3), 75e17);
        assertEq(usdc.balanceOf(add3), 500e6);
        assertEq(cbdToken.balanceOf(add2), 75e17 + 5e18*500e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add1),initialReward + reward1*500e18/1000e18 + reward2*500e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add2), initialReward + reward1*500e18/1000e18);
        vm.stopPrank();
        // console.log("time", block.timestamp + 1095 days);
        // buy token add4
        vm.startPrank(add4);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 500e6);
        purchaseContract.buyToken(500e6, add3);
        assertEq(cbdToken.balanceOf(add4), 75e17);
        assertEq(usdc.balanceOf(add4), 500e6);
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
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 500e6);
        purchaseContract.buyToken(500e6, add4);
        assertEq(cbdToken.balanceOf(add5), 75e17);
        assertEq(usdc.balanceOf(add5), 500e6);
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
        usdc.transfer(add2, 500e6);
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 500e6);
        purchaseContract.buyToken(500e6, add1);
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
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 250e6);
        purchaseContract.buyToken(250e6, address(0));
        assertEq(cbdToken.balanceOf(add1), 25e17);
        assertEq(usdc.balanceOf(add1), 750e6);
        vm.stopPrank();
        
        // buy token add2
        vm.startPrank(add2);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 250e6);
        purchaseContract.buyToken(250e6, add1);
        assertEq(cbdToken.balanceOf(add2), 25e17);
        assertEq(usdc.balanceOf(add2), 750e6);
        assertEq(cbdToken.balanceOf(add1), 25e17 + 5e18*250e18/1000e18);
        assertEq(purchaseContract.allRewardAmounts(add1), initialReward + reward1*250e18/1000e18);
        console.logUint(cbdToken.balanceOf(add1));
        vm.stopPrank();
    }
    
    
    function testbuyTokenWithoutRef() public {
        usdc.transfer(add1, 4000e6);
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 5000e6);
        purchaseContract.buyTokenWithoutRef(5000e6);
        assertEq(cbdToken.balanceOf(add1), 250e18);
        assertEq(usdc.balanceOf(add1), 0);
        vm.stopPrank();
    }

    function testRegistered() public {
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 250e6);
        vm.expectRevert("You are not registered");
        purchaseContract.buyToken(250e6, address(0));
    }

    // function consoleRewards(address _user) public view {
    //     Purchase.UserRewards[] memory rewardS = purchaseContract.userRewards(
    //         _user
    //     );
    //     for (uint256 i; i < rewardS.length; i++) {
    //         console.log("Reward", i, rewardS[i].rewardAmount);
    //         console.log("EndTime", i, rewardS[i].endTime);
    //         console.log("LastUpdate", i, rewardS[i].lastUpdateTime);
    //         console.log("...........");
    //     }
    //     // console.log('..........................................');
    // }


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
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 250e6);
        purchaseContract.buyToken(250e6, address(0));
        assertEq(cbdToken.balanceOf(add1), 25e17);
        assertEq(usdc.balanceOf(add1), 750e6);
        assertEq(usdc.balanceOf(newAdmin), 250e6 + 50e6);
        vm.stopPrank();
    }


    function testPurchaseAdminWithoutRefer() public {
        purchaseContract.changeAdmin(newAdmin);
        usdc.transfer(add1, 4000e6);
        vm.startPrank(add1);
        usdc.approve(address(purchaseContract), 50e6);
        purchaseContract.register(50e6, address(0));
        usdc.approve(address(purchaseContract), 5000e6);
        purchaseContract.buyTokenWithoutRef(5000e6);
        assertEq(cbdToken.balanceOf(add1), 250e18);
        assertEq(usdc.balanceOf(add1), 0);
        assertEq(usdc.balanceOf(newAdmin), 5000e6 + 50e6);
        vm.stopPrank();
    }
    
    
}

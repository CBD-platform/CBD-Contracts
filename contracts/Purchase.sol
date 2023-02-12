// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
// pragma abicoderv2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CBDToken.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract Purchase is Ownable {
    CBDToken public cbdToken;
    address public purchaseToken;
    uint256 public tokenPrice;
     AggregatorV3Interface public priceFeed;


    struct UserRewards {
        uint256 rewardAmount;
        uint256 endTime;
        uint256 lastUpdateTime;
    }

    /**
    @param _cbdToken : CBD token address
    @param _purchaseToken : address of the stablecoin that user can pay for buy
    @param _tokenPrice: price of each token. This price should be in format of purchase token.(if purchase token has 18 decimals, this input amount should has 18 decimals too)
    @notice usdc on polygon has 6 decimals so price should has 6 decimals
     */
    constructor(
        address _cbdToken,
        address _purchaseToken,
        uint256 _tokenPrice,
        address _priceFeed
    ) {
        cbdToken = CBDToken(_cbdToken);
        purchaseToken = _purchaseToken;
        tokenPrice = _tokenPrice;
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    mapping(address => UserRewards[]) public rewards;
    mapping(address => address) public refer;


    
    function scalePrice(
        int256 _price,
        uint8 _priceDecimals,
        uint8 _decimals
    ) internal pure returns (int256) {
        if (_priceDecimals < _decimals) {
            return _price * int256(10 ** uint256(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return _price / int256(10 ** uint256(_priceDecimals - _decimals));
        }
        return _price;
    }

    function getOracleUsdcPrice() public view returns (uint) {
        (,int price,,,) = priceFeed.latestRoundData();
        uint8 baseDecimals = priceFeed.decimals();
        int basePrice = scalePrice(price, baseDecimals, 18);
        return uint(basePrice);
    }


    //set purchase token
    function setPurchaseToken(address _purchaseToken) public onlyOwner {
        require(
            _purchaseToken != address(0),
            "Purchase token can not be zero address"
        );
        purchaseToken = _purchaseToken;
    }

    //set CBD token
    function setCBDToken(address _CBDToken) public onlyOwner {
        require(_CBDToken != address(0), "CBD token can not be zero address");
        cbdToken = CBDToken(_CBDToken);
    }

    //return all rewards of a user (in an array of the structurs)
    function userRewards(address _user)
        public
        view
        returns (UserRewards[] memory)
    {
        return rewards[_user];
    }

    //return all reward amounts of a user
    function allRewardAmounts(address _user) public view returns (uint256) {
        uint256 allRewards = 0;
        for (uint256 i = 0; i < rewards[_user].length; i++) {
            if (rewards[_user][i].rewardAmount > 0) {
                allRewards += rewards[_user][i].rewardAmount;
            }
        }
        return allRewards;
    }

    function getUnclaimedRewards(address _user) public view returns (uint256) {
        uint256 unClaimedRewards = 0;
        for (uint256 i = 0; i < rewards[_user].length; i++) {
            if (rewards[_user][i].rewardAmount > 0) {
                if (block.timestamp < rewards[_user][i].endTime) {
                    uint256 allRemainPeriod = rewards[_user][i].endTime -
                        rewards[_user][i].lastUpdateTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        rewards[_user][i].lastUpdateTime;
                    uint256 unClaimedAmount = (rewards[_user][i].rewardAmount *
                        unClaimedPeriod) / allRemainPeriod;
                    unClaimedRewards += unClaimedAmount;
                } else {
                    unClaimedRewards += rewards[_user][i].rewardAmount;
                }
            }
        }
        return unClaimedRewards;
    }

    /**
    @dev set token price by the owner (should be in wei)
    @param _newTokenPrice should be on format of purchase token price (18 decimal or other)
    @notice usdc on polygon has 6 decimals so price should has 6 decimals
     */
    function setTokenPrice(uint256 _newTokenPrice) public onlyOwner {
        tokenPrice = _newTokenPrice;
    }

    /**
    @dev user can buy token by paying stable coin
    all stable coin will be transfered to the wallet of owner
    first smart contract perform purchase actions for the user after that four up level inviters will receive rewards
    @param stableCoinAmount is number of tokens that user wants to buy (should be in wei format without number)
    @param _refer is an address that invite user with referral link to buy token
     */
    function buyToken(uint256 stableCoinAmount, address _refer) public {
        uint usdcOraclePrice = getOracleUsdcPrice();
        require(usdcOraclePrice >= 95e16, "USDC price is not above 0.95 $");
        uint256 purchaseTokenDecimals = ERC20(purchaseToken).decimals();
        // require(
        //     stableCoinAmount == 500 * 10**purchaseTokenDecimals ||
        //         stableCoinAmount == 1000 * 10**purchaseTokenDecimals ||
        //         stableCoinAmount == 2000 * 10**purchaseTokenDecimals, "Stable coin amount should be 500$ or 100$ or 2000$"
        // );
        require(_refer != msg.sender, "You can't put your address as refer");
        require(
            IERC20(purchaseToken).balanceOf(msg.sender) >= stableCoinAmount,
            "You don't have enough stablecoin balance to buy"
        );
        uint256 quantity = (stableCoinAmount * 1e18) / tokenPrice;
        uint256 baseQuantity = 1000*10**purchaseTokenDecimals* 1e18/tokenPrice;
        //perform purchase for user
        cbdToken.mint(msg.sender, quantity);
        SafeERC20.safeTransferFrom(
            IERC20(purchaseToken),
            msg.sender,
            owner(),
            stableCoinAmount
        );
        //give refers rewards
        if (_refer != address(0)) {
            //set _refer for msg.sender
            refer[msg.sender] = _refer;
            // extract refers
            address refer1 = _refer;
            address refer2 = refer[refer1];
            address refer3 = refer[refer2];
            address refer4 = refer[refer3];
            // set refer1 rewards
            if (refer1 != address(0) && cbdToken.balanceOf(refer1) > 0) {
                cbdToken.mint(refer1, 5e18*quantity/baseQuantity);
                rewards[refer1].push(
                    UserRewards(
                        95e17*quantity/baseQuantity,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
            }
            // set refer2 rewards
            if (refer2 != address(0) && cbdToken.balanceOf(refer2) > 0) {
                rewards[refer2].push(
                    UserRewards(
                        75e17*quantity/baseQuantity,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
            }
            // set refer3 rewards
            if (refer3 != address(0) && cbdToken.balanceOf(refer3) > 0) {
                rewards[refer3].push(
                    UserRewards(
                        6e18*quantity/baseQuantity,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
            }
            // set refer4 rewards
            if (refer4 != address(0) && cbdToken.balanceOf(refer4) > 0) {
                rewards[refer4].push(
                    UserRewards(
                        4e18*quantity/baseQuantity,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
            }
        }
    }


    function buyTokenWhitoutRef(uint256 stableCoinAmount) public {
        uint usdcOraclePrice = getOracleUsdcPrice();
        require(usdcOraclePrice >= 95e16, "USDC price is not above 0.95 $");
        require(
            IERC20(purchaseToken).balanceOf(msg.sender) >= stableCoinAmount,
            "You don't have enough stablecoin balance to buy"
        );
        uint256 quantity = (stableCoinAmount * 1e18) / tokenPrice;
        //perform purchase for user
        cbdToken.mint(msg.sender, quantity);
        SafeERC20.safeTransferFrom(
            IERC20(purchaseToken),
            msg.sender,
            owner(),
            stableCoinAmount
        );
    }

    function _deleteRewardObject(address _user, uint256 _rewardIndex) internal {
        for (uint256 i = _rewardIndex; i < rewards[_user].length - 1; i++) {
            rewards[_user][i] = rewards[_user][i + 1];
        }
        delete rewards[_user][rewards[_user].length - 1];
        rewards[_user].pop();
    }

    //claim rewards by the user
    function claimRewards() public {
        for (uint256 i = 0; i < rewards[msg.sender].length; i++) {
            if (rewards[msg.sender][i].rewardAmount > 0) {
                if (block.timestamp < rewards[msg.sender][i].endTime) {
                    uint256 allRemainPeriod = rewards[msg.sender][i].endTime -
                        rewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        rewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedAmount = (rewards[msg.sender][i]
                        .rewardAmount * unClaimedPeriod) / allRemainPeriod;
                    rewards[msg.sender][i].rewardAmount -= unClaimedAmount;
                    rewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    if (rewards[msg.sender][i].rewardAmount == 0) {
                        _deleteRewardObject(msg.sender, i);
                    }
                    cbdToken.mint(msg.sender, unClaimedAmount);
                } else {
                    uint256 unClaimedAmount = rewards[msg.sender][i]
                        .rewardAmount;
                    rewards[msg.sender][i].rewardAmount = 0;
                    rewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    cbdToken.mint(msg.sender, unClaimedAmount);
                }
            }
        }

        for (uint256 i = 0; i < rewards[msg.sender].length; i++) {
            if (rewards[msg.sender][i].rewardAmount == 0) {
                _deleteRewardObject(msg.sender, i);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
// pragma abicoderv2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CBDToken.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Purchase {
    CBDToken public cbdToken;
    address public purchaseToken;
    uint256 public tokenPrice;
    uint256 public baseRegisterAmount;
    AggregatorV3Interface public priceFeed;

    address public admin;
    mapping(address => bool) public owners; //is given address owner
    mapping(address => bool) public isRegistered;

    bool onlyAllowedAmountsStatus;
    mapping(uint => AllowedAmount) public allowedAmounts;
    
    
    struct AllowedAmount {
        bool isAllowed;
        uint totalReward;
    }

    struct UserRewards {
        uint256 totalRewardAmount;
        uint256 rewardAmount;
        uint256 endTime;
        uint256 lastUpdateTime;
    }

    struct Cbd2Rewards {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
    }

    //events
    event TransferUserOwnership(address _from, address _to);
    event AddOwner(address _newOwner);
    event RemoveOwner(address _removedOwner);
    event ChangeAdmin(address _newAdmin);
    event SetPurchaseToken(address _newToken);
    event ChangeAllowAmountsActivation(bool _status);
    event EnableAllawanceForAmount(uint _amount, uint _totalRewardByAmount);
    event DisableAllawanceForAmount(uint _amount);
    event SetCBDToken(address _CBDToken);
    event SetBaseRegisterAmount(uint256 _baseRegisterAmount);
    event SetTokenPrice(uint256 _newTokenPrice);
    event Register(address _user, uint _stableCointAmount, address _refer);
    event BuyToken(address _user, uint256 stableCoinAmount, address _refer1, address _refer2, address _refer3, address _refer4);
    event BuyTokenWithoutRef(address _user, uint256 stableCoinAmount);
    event ClaimRewards(address _user);
    event ClaimPurchaseRewards(address _user);
    event ClaimReferRewards(address _user);
    

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
        uint256 purchaseTokenDecimals = ERC20(purchaseToken).decimals();
        baseRegisterAmount = 50*10**purchaseTokenDecimals;
        //set owner and admin
        owners[msg.sender] = true;
        admin = msg.sender;
        //allowed amounts
        onlyAllowedAmountsStatus = true;
        enableAllawanceForAmount(250*10**purchaseTokenDecimals, 500*10**purchaseTokenDecimals);
        enableAllawanceForAmount(500*10**purchaseTokenDecimals, 1500*10**purchaseTokenDecimals);
        enableAllawanceForAmount(1000*10**purchaseTokenDecimals, 3000*10**purchaseTokenDecimals);
        enableAllawanceForAmount(2000*10**purchaseTokenDecimals, 6000*10**purchaseTokenDecimals);
    }

    
    mapping(address => UserRewards[]) public purchaseRewards;
    mapping(address => UserRewards[]) public referRewards;
    mapping(address => address) public refer;
    mapping(address => address[]) public referredPeople;
    //history
    mapping(address => uint) public instantReferRewardHistory;
    mapping(address => uint) public dailyReferRewardHistory;
    mapping(address => uint) public boughtMembershipHistory;
    mapping(address => uint) public boughtInvestingHistory;
    //cbd2
    mapping(address => Cbd2Rewards[]) public cbd2Rewards;



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
    
    
    // Check msg.sender should be owner
    function _checkOwners() internal view virtual {
        require(owners[msg.sender], "Ownable_Distributor: caller is not from the owners");
    }
    

    function transferUserOwnership(address _newOwner) public onlyOwners{
        owners[msg.sender] = false;
        owners[_newOwner] = true;

        emit TransferUserOwnership(msg.sender, _newOwner);
    }

    function addOwner(address _newOwner) public onlyOwners{
        owners[_newOwner] = true;

        emit AddOwner(_newOwner);
    }

    function removeOwner(address _newOwner) public onlyOwners{
        owners[_newOwner] = false;
        emit RemoveOwner(_newOwner);
    }

    function changeAdmin(address _newAdmin) public onlyOwners{
        admin = _newAdmin;
        emit ChangeAdmin(_newAdmin);
    }


    function scalePrice(
        int256 _price,
        uint8 _priceDecimals,
        uint8 _decimals
    ) internal pure returns (int256) {
        if (_priceDecimals < _decimals) {
            return _price * int256(10**uint256(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return _price / int256(10**uint256(_priceDecimals - _decimals));
        }
        return _price;
    }

    function getOracleUsdcPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint8 baseDecimals = priceFeed.decimals();
        int256 basePrice = scalePrice(price, baseDecimals, 18);
        return uint256(basePrice);
    }

    //set purchase token
    function setPurchaseToken(address _purchaseToken) public onlyOwners {
        require(
            _purchaseToken != address(0),
            "Purchase token can not be zero address"
        );
        purchaseToken = _purchaseToken;
        emit SetPurchaseToken(_purchaseToken);
    }

    // enable or disable allowAmounts trading
    function changeAllowAmountsActivation(bool _status) public onlyOwners {
        onlyAllowedAmountsStatus = _status;
        emit ChangeAllowAmountsActivation(_status);
    }

    // allow amounts trading
    function enableAllawanceForAmount(uint _amount, uint _totalRewardByAmount) public onlyOwners {
        allowedAmounts[_amount].isAllowed = true;
        allowedAmounts[_amount].totalReward = _totalRewardByAmount;
        emit EnableAllawanceForAmount(_amount, _totalRewardByAmount);
    }

    // disAllow amounts trading
    function disableAllawanceForAmount(uint _amount) public onlyOwners {
        allowedAmounts[_amount].isAllowed = false;
        allowedAmounts[_amount].totalReward = 0;
        emit DisableAllawanceForAmount(_amount);
    }



    //set CBD token
    function setCBDToken(address _CBDToken) public onlyOwners {
        require(_CBDToken != address(0), "CBD token can not be zero address");
        cbdToken = CBDToken(_CBDToken);
        emit SetCBDToken(_CBDToken);

    }

    function setBaseRegisterAmount(uint256 _baseRegisterAmount) public onlyOwners {
        require(_baseRegisterAmount != 0, "Base register amount can not be zero");
        baseRegisterAmount = _baseRegisterAmount;
        emit SetBaseRegisterAmount(_baseRegisterAmount);
    }

    // referredPeople
    function userReferredPeople(address _user)
        public
        view
        returns (address[] memory)
    {
        return referredPeople[_user];
    }

    //return all purchse rewards of a user (in an array of the structurs)
    function userPurchaseRewards(address _user)
        public
        view
        returns (UserRewards[] memory)
    {
        return purchaseRewards[_user];
    }

    //return all purchse rewards of a user (in an array of the structurs)
    function userReferRewards(address _user)
        public
        view
        returns (UserRewards[] memory)
    {
        return referRewards[_user];
    }

    //return all cbd2 rewards of a user (in an array of the structurs)
    function userCbd2Rewards(address _user)
        public
        view
        returns (Cbd2Rewards[] memory)
    {
        return cbd2Rewards[_user];
    }

    //return all purchase reward amounts of a user
    function allPurchaseRewardAmounts(address _user) public view returns (uint256) {
        uint256 allRewards = 0;
        for (uint256 i = 0; i < purchaseRewards[_user].length; i++) {
            if (purchaseRewards[_user][i].rewardAmount > 0) {
                allRewards += purchaseRewards[_user][i].rewardAmount;
            }
        }
        return allRewards;
    }


    //return all refer reward amounts of a user
    function allReferRewardAmounts(address _user) public view returns (uint256) {
        uint256 allRewards = 0;
        for (uint256 i = 0; i < referRewards[_user].length; i++) {
            if (referRewards[_user][i].rewardAmount > 0) {
                allRewards += referRewards[_user][i].rewardAmount;
            }
        }
        return allRewards;
    }

    //return all reward amounts of a user (purchase rewards + refer rewards)
    function allRewardAmounts(address _user) public view returns (uint256) {
        uint256 allRewards = 0;
        for (uint256 i = 0; i < purchaseRewards[_user].length; i++) {
            if (purchaseRewards[_user][i].rewardAmount > 0) {
                allRewards += purchaseRewards[_user][i].rewardAmount;
            }
        }
        for (uint256 i = 0; i < referRewards[_user].length; i++) {
            if (referRewards[_user][i].rewardAmount > 0) {
                allRewards += referRewards[_user][i].rewardAmount;
            }
        }
        return allRewards;
    }

    //return all cbd2 reward amounts of a user
    function allCb2RewardAmounts(address _user) public view returns (uint256) {
        uint256 allRewards = 0;
        for (uint256 i = 0; i < cbd2Rewards[_user].length; i++) {
            if (cbd2Rewards[_user][i].amount > 0) {
                allRewards += cbd2Rewards[_user][i].amount;
            }
        }
        return allRewards;
    }

    //return all purchase reward amounts of a user
    function allPurchaseTotalRewardAmounts(address _user) public view returns (uint256) {
        uint256 allTotalRewards = 0;
        for (uint256 i = 0; i < purchaseRewards[_user].length; i++) {
            if (purchaseRewards[_user][i].totalRewardAmount > 0) {
                allTotalRewards += purchaseRewards[_user][i].totalRewardAmount;
            }
        }
        return allTotalRewards;
    }


    //return all refer reward amounts of a user
    function allReferTotalRewardAmounts(address _user) public view returns (uint256) {
        uint256 allTotalRewards = 0;
        for (uint256 i = 0; i < referRewards[_user].length; i++) {
            if (referRewards[_user][i].totalRewardAmount > 0) {
                allTotalRewards += referRewards[_user][i].totalRewardAmount;
            }
        }
        return allTotalRewards;
    }

    //return all reward amounts of a user (purchase rewards + refer rewards)
    function allTotalRewardAmounts(address _user) public view returns (uint256) {
        uint256 allTotalRewards = 0;
        for (uint256 i = 0; i < purchaseRewards[_user].length; i++) {
            if (purchaseRewards[_user][i].totalRewardAmount > 0) {
                allTotalRewards += purchaseRewards[_user][i].totalRewardAmount;
            }
        }
        for (uint256 i = 0; i < referRewards[_user].length; i++) {
            if (referRewards[_user][i].totalRewardAmount > 0) {
                allTotalRewards += referRewards[_user][i].totalRewardAmount;
            }
        }
        return allTotalRewards;
    }

    function getUnclaimedRewards(address _user) public view returns (uint256) {
        uint256 unClaimedRewards = 0;
        //for purchase rewards
        for (uint256 i = 0; i < purchaseRewards[_user].length; i++) {
            if (purchaseRewards[_user][i].rewardAmount > 0) {
                if (block.timestamp < purchaseRewards[_user][i].endTime) {
                    uint256 allRemainPeriod = purchaseRewards[_user][i].endTime -
                        purchaseRewards[_user][i].lastUpdateTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        purchaseRewards[_user][i].lastUpdateTime;
                    uint256 unClaimedAmount = (purchaseRewards[_user][i].rewardAmount *
                        unClaimedPeriod) / allRemainPeriod;
                    unClaimedRewards += unClaimedAmount;
                } else {
                    unClaimedRewards += purchaseRewards[_user][i].rewardAmount;
                }
            }
        }
        //for refer rewards
        for (uint256 i = 0; i < referRewards[_user].length; i++) {
            if (referRewards[_user][i].rewardAmount > 0) {
                if (block.timestamp < referRewards[_user][i].endTime) {
                    uint256 allRemainPeriod = referRewards[_user][i].endTime -
                        referRewards[_user][i].lastUpdateTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        referRewards[_user][i].lastUpdateTime;
                    uint256 unClaimedAmount = (referRewards[_user][i].rewardAmount *
                        unClaimedPeriod) / allRemainPeriod;
                    unClaimedRewards += unClaimedAmount;
                } else {
                    unClaimedRewards += referRewards[_user][i].rewardAmount;
                }
            }
        }
        return unClaimedRewards;
    }


    function getCb2RewardsUntillNow(address _user) public view returns (uint256) {
        uint256 unClaimedRewards = 0;
        //for cbd rewards
        for (uint256 i = 0; i < cbd2Rewards[_user].length; i++) {
            if (cbd2Rewards[_user][i].amount > 0) {
                if (block.timestamp < cbd2Rewards[_user][i].endTime) {
                    uint256 allRemainPeriod = cbd2Rewards[_user][i].endTime -
                        cbd2Rewards[_user][i].startTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        cbd2Rewards[_user][i].startTime;
                    uint256 unClaimedAmount = (cbd2Rewards[_user][i].amount *
                        unClaimedPeriod) / allRemainPeriod;
                    unClaimedRewards += unClaimedAmount;
                } else {
                    unClaimedRewards += cbd2Rewards[_user][i].amount;
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
    function setTokenPrice(uint256 _newTokenPrice) public onlyOwners {
        tokenPrice = _newTokenPrice;
        emit SetTokenPrice(_newTokenPrice);
    }

    /**
    @dev User first should buy 80 usd tokens to be registered
    all stable coin will be transfered to the wallet of owner
    first smart contract perform purchase actions for the user after that four up level inviters will receive rewards
    @param stableCoinAmount is number of tokens that user wants to buy (should be in wei format without number)
    @param _refer is an address that invite user with referral link to buy token
    */
    function register(uint256 stableCoinAmount, address _refer) public {
        if(_refer != address(0)){
        require(isRegistered[_refer] == true, "Your refer is not registered");
        }
        require(stableCoinAmount >= baseRegisterAmount, "Your amount is lower than the base register amount");
        uint256 usdcOraclePrice = getOracleUsdcPrice();
        require(usdcOraclePrice >= 95e16, "USDC price is not above 0.95 $");
        require(_refer != msg.sender, "You can't put your address as refer");
        require(
            IERC20(purchaseToken).balanceOf(msg.sender) >= stableCoinAmount,
            "You don't have enough stablecoin balance to buy"
        );
        SafeERC20.safeTransferFrom(
            IERC20(purchaseToken),
            msg.sender,
            admin,
            stableCoinAmount
        );
        isRegistered[msg.sender] = true;
        if(refer[msg.sender] == address(0) && _refer != address(0)){
                // store msg.sender as refferedPeople for refer
                referredPeople[_refer].push(msg.sender);
                //set _refer for msg.sender
                refer[msg.sender] = _refer;
            }
        emit Register(msg.sender, stableCoinAmount, _refer);
    }

    /**
    @dev user can buy token by paying stable coin
    all stable coin will be transfered to the wallet of owner
    first smart contract perform purchase actions for the user after that four up level inviters will receive rewards
    @param stableCoinAmount is number of tokens that user wants to buy (should be in wei format without number)
    @param _refer is an address that invite user with referral link to buy token
    */
    function buyToken(uint256 stableCoinAmount, address _refer) public {
        require(isRegistered[msg.sender] == true, "You are not registered");
        if(_refer != address(0)){
        require(isRegistered[_refer] == true, "Your refer is not registered");
        }
        uint256 usdcOraclePrice = getOracleUsdcPrice();
        require(usdcOraclePrice >= 95e16, "USDC price is not above 0.95 $");
        uint256 purchaseTokenDecimals = ERC20(purchaseToken).decimals();
        require(_refer != msg.sender, "You can't put your address as refer");
        require(
            IERC20(purchaseToken).balanceOf(msg.sender) >= stableCoinAmount,
            "You don't have enough stablecoin balance to buy"
        );
        uint256 quantity = (stableCoinAmount * 1e18) / tokenPrice;
        uint256 baseQuantity = (1000 * 10**purchaseTokenDecimals * 1e18) /
            tokenPrice;

        if(onlyAllowedAmountsStatus == true){
            require(allowedAmounts[stableCoinAmount].isAllowed, "This stable coin amount is not allowed");
            uint allQuantityByReward = (allowedAmounts[stableCoinAmount].totalReward * 1e18) / tokenPrice;
            cbdToken.mint(msg.sender, allQuantityByReward*10/100);
            SafeERC20.safeTransferFrom(
                IERC20(purchaseToken),
                msg.sender,
                admin,
                stableCoinAmount
            );
            purchaseRewards[msg.sender].push(
                    UserRewards(
                        allQuantityByReward*90/100,
                        allQuantityByReward*90/100,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
            //store cbbd2
            cbd2Rewards[msg.sender].push(
                Cbd2Rewards(
                    stableCoinAmount*1e18/10**ERC20(purchaseToken).decimals(),
                    block.timestamp,
                    block.timestamp + 1095 days
                )
            );                
        }else{
        //perform purchase for user
        cbdToken.mint(msg.sender, quantity);
        SafeERC20.safeTransferFrom(
            IERC20(purchaseToken),
            msg.sender,
            admin,
            stableCoinAmount
        );
        }

        //give refers rewards
        if (_refer != address(0)) {
            if(refer[msg.sender] == address(0)){
                // store msg.sender as refferedPeople for refer
                referredPeople[_refer].push(msg.sender);
                //set _refer for msg.sender
                refer[msg.sender] = _refer;
            }
            // extract refers
            address refer1 = refer[msg.sender];
            address refer2 = refer[refer1];
            address refer3 = refer[refer2];
            address refer4 = refer[refer3];
            // set refer1 rewards
            if (refer1 != address(0) && cbdToken.balanceOf(refer1) > 0) {
                cbdToken.mint(refer1, (5e18 * quantity) / baseQuantity);
                instantReferRewardHistory[refer1] += ((5e18 * quantity) / baseQuantity);
                referRewards[refer1].push(
                    UserRewards(
                        (95e17 * quantity) / baseQuantity,
                        (95e17 * quantity) / baseQuantity,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
                dailyReferRewardHistory[refer1] += (95e17 * quantity) / baseQuantity;
            }
            // set refer2 rewards
            if (refer2 != address(0) && cbdToken.balanceOf(refer2) > 0) {
                referRewards[refer2].push(
                    UserRewards(
                        (75e17 * quantity) / baseQuantity,
                        (75e17 * quantity) / baseQuantity,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
                dailyReferRewardHistory[refer2] += (75e17 * quantity) / baseQuantity;
            }
            // set refer3 rewards
            if (refer3 != address(0) && cbdToken.balanceOf(refer3) > 0) {
                referRewards[refer3].push(
                    UserRewards(
                        (6e18 * quantity) / baseQuantity,
                        (6e18 * quantity) / baseQuantity,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
                dailyReferRewardHistory[refer3] += (6e18 * quantity) / baseQuantity;
            }
            // set refer4 rewards
            if (refer4 != address(0) && cbdToken.balanceOf(refer4) > 0) {
                referRewards[refer4].push(
                    UserRewards(
                        (4e18 * quantity) / baseQuantity,
                        (4e18 * quantity) / baseQuantity,
                        block.timestamp + 1095 days,
                        block.timestamp
                    )
                );
                dailyReferRewardHistory[refer4] += (4e18 * quantity) / baseQuantity;
            }
            emit BuyToken(msg.sender, stableCoinAmount, refer1, refer2, refer3, refer4);
        }
        boughtMembershipHistory[msg.sender] += stableCoinAmount;
        emit BuyToken(msg.sender, stableCoinAmount, _refer, address(0), address(0), address(0));

    }

    function buyTokenWithoutRef(uint256 stableCoinAmount) public {
        require(isRegistered[msg.sender] == true, "You are not registered");
        uint256 usdcOraclePrice = getOracleUsdcPrice();
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
            admin,
            stableCoinAmount
        );
        boughtInvestingHistory[msg.sender] += stableCoinAmount;
        emit BuyTokenWithoutRef(msg.sender, stableCoinAmount);
    }

    function _deletePurchaseRewardObject(address _user, uint256 _rewardIndex) internal {
        for (uint256 i = _rewardIndex; i < purchaseRewards[_user].length - 1; i++) {
            purchaseRewards[_user][i] = purchaseRewards[_user][i + 1];
        }
        delete purchaseRewards[_user][purchaseRewards[_user].length - 1];
        purchaseRewards[_user].pop();
    }


    function _deleteReferRewardObject(address _user, uint256 _rewardIndex) internal {
        for (uint256 i = _rewardIndex; i < referRewards[_user].length - 1; i++) {
            referRewards[_user][i] = referRewards[_user][i + 1];
        }
        delete referRewards[_user][referRewards[_user].length - 1];
        referRewards[_user].pop();
    }

    //claim rewards by the user
    function claimRewards() public {
        uint tokenAmountToMint;
        // calculate purchase rewards
        for (uint256 i = 0; i < purchaseRewards[msg.sender].length; i++) {
            if (purchaseRewards[msg.sender][i].rewardAmount > 0) {
                if (block.timestamp < purchaseRewards[msg.sender][i].endTime) {
                    uint256 allRemainPeriod = purchaseRewards[msg.sender][i].endTime -
                        purchaseRewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        purchaseRewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedAmount = (purchaseRewards[msg.sender][i]
                        .rewardAmount * unClaimedPeriod) / allRemainPeriod;
                    purchaseRewards[msg.sender][i].rewardAmount -= unClaimedAmount;
                    purchaseRewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    if (purchaseRewards[msg.sender][i].rewardAmount == 0) {
                        _deletePurchaseRewardObject(msg.sender, i);
                    }
                    tokenAmountToMint += unClaimedAmount;
                } else {
                    uint256 unClaimedAmount = purchaseRewards[msg.sender][i]
                        .rewardAmount;
                    purchaseRewards[msg.sender][i].rewardAmount = 0;
                    purchaseRewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    tokenAmountToMint += unClaimedAmount;
                }
            }
        }
        // calculate refer rewards
        for (uint256 i = 0; i < referRewards[msg.sender].length; i++) {
            if (referRewards[msg.sender][i].rewardAmount > 0) {
                if (block.timestamp < referRewards[msg.sender][i].endTime) {
                    uint256 allRemainPeriod = referRewards[msg.sender][i].endTime -
                        referRewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        referRewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedAmount = (referRewards[msg.sender][i]
                        .rewardAmount * unClaimedPeriod) / allRemainPeriod;
                    referRewards[msg.sender][i].rewardAmount -= unClaimedAmount;
                    referRewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    if (referRewards[msg.sender][i].rewardAmount == 0) {
                        _deleteReferRewardObject(msg.sender, i);
                    }
                    tokenAmountToMint += unClaimedAmount;
                } else {
                    uint256 unClaimedAmount = referRewards[msg.sender][i]
                        .rewardAmount;
                    referRewards[msg.sender][i].rewardAmount = 0;
                    referRewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    tokenAmountToMint += unClaimedAmount;
                }
            }
        }
        cbdToken.mint(msg.sender, tokenAmountToMint);
        emit ClaimRewards(msg.sender);
        //delet zero purchase object
        for (uint256 i = 0; i < purchaseRewards[msg.sender].length; i++) {
            if (purchaseRewards[msg.sender][i].rewardAmount == 0) {
                _deletePurchaseRewardObject(msg.sender, i);
            }
        }
        //delet zero refer object
        for (uint256 i = 0; i < referRewards[msg.sender].length; i++) {
            if (referRewards[msg.sender][i].rewardAmount == 0) {
                _deleteReferRewardObject(msg.sender, i);
            }
        }
    }



    //claim only purchase rewards by the user
    function claimPurchaseRewards() public {
        uint tokenAmountToMint;
        // calculate purchase rewards
        for (uint256 i = 0; i < purchaseRewards[msg.sender].length; i++) {
            if (purchaseRewards[msg.sender][i].rewardAmount > 0) {
                if (block.timestamp < purchaseRewards[msg.sender][i].endTime) {
                    uint256 allRemainPeriod = purchaseRewards[msg.sender][i].endTime -
                        purchaseRewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        purchaseRewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedAmount = (purchaseRewards[msg.sender][i]
                        .rewardAmount * unClaimedPeriod) / allRemainPeriod;
                    purchaseRewards[msg.sender][i].rewardAmount -= unClaimedAmount;
                    purchaseRewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    if (purchaseRewards[msg.sender][i].rewardAmount == 0) {
                        _deletePurchaseRewardObject(msg.sender, i);
                    }
                    tokenAmountToMint += unClaimedAmount;
                } else {
                    uint256 unClaimedAmount = purchaseRewards[msg.sender][i]
                        .rewardAmount;
                    purchaseRewards[msg.sender][i].rewardAmount = 0;
                    purchaseRewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    tokenAmountToMint += unClaimedAmount;
                }
            }
        }
        
        cbdToken.mint(msg.sender, tokenAmountToMint);
        emit ClaimPurchaseRewards(msg.sender);
        //delet zero purchase object
        for (uint256 i = 0; i < purchaseRewards[msg.sender].length; i++) {
            if (purchaseRewards[msg.sender][i].rewardAmount == 0) {
                _deletePurchaseRewardObject(msg.sender, i);
            }
        }
    }


    //claim refer rewards by the user
    function claimReferRewards() public {
        uint tokenAmountToMint;
        
        // calculate refer rewards
        for (uint256 i = 0; i < referRewards[msg.sender].length; i++) {
            if (referRewards[msg.sender][i].rewardAmount > 0) {
                if (block.timestamp < referRewards[msg.sender][i].endTime) {
                    uint256 allRemainPeriod = referRewards[msg.sender][i].endTime -
                        referRewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedPeriod = block.timestamp -
                        referRewards[msg.sender][i].lastUpdateTime;
                    uint256 unClaimedAmount = (referRewards[msg.sender][i]
                        .rewardAmount * unClaimedPeriod) / allRemainPeriod;
                    referRewards[msg.sender][i].rewardAmount -= unClaimedAmount;
                    referRewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    if (referRewards[msg.sender][i].rewardAmount == 0) {
                        _deleteReferRewardObject(msg.sender, i);
                    }
                    tokenAmountToMint += unClaimedAmount;
                } else {
                    uint256 unClaimedAmount = referRewards[msg.sender][i]
                        .rewardAmount;
                    referRewards[msg.sender][i].rewardAmount = 0;
                    referRewards[msg.sender][i].lastUpdateTime = block.timestamp;
                    tokenAmountToMint += unClaimedAmount;
                }
            }
        }
        cbdToken.mint(msg.sender, tokenAmountToMint);
        emit ClaimReferRewards(msg.sender);
        //delet zero refer object
        for (uint256 i = 0; i < referRewards[msg.sender].length; i++) {
            if (referRewards[msg.sender][i].rewardAmount == 0) {
                _deleteReferRewardObject(msg.sender, i);
            }
        }
    }
}

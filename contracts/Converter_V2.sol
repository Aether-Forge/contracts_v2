// SPDX-License-Identifier: MIT

// solhint-disable-next-line
pragma solidity ^0.8.25;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IToken.sol";

import "hardhat/console.sol";

contract COEConverter_V2 is Initializable {
    address public aegToken;
    address public wAegToken;
    address public cards;
    address public ethernals;
    address public adventurers;
    address public emotes;
    address public cardBacks;
    address public paymentReceiver;
    bool public paused;
    bool public useChainlink;

    AggregatorV3Interface public aegUsdPriceFeed;
    IUniswapV3Pool public uniswapV3Pool;

    event ConvertedCards(
        address indexed _assetAddress,
        address indexed _userAddress,
        uint256[] _ids,
        uint256[] _amounts
    );

    function initialize(
        address _aegToken,
        address _wAegToken,
        // address _usdcToken,
        // address _usdtToken,
        address _cards,
        address _ethernals,
        address _adventurers,
        address _emotes,
        address _cardBacks,
        address _aegUsdPriceFeed, // Address of the AEG/USD Chainlink price feed
        address _uniswapV3Pool, // Address of the Uniswap V3 Pool
        bool _useChainlink // Boolean to switch between Chainlink and Uniswap
    ) public initializer {
        aegUsdPriceFeed = AggregatorV3Interface(_aegUsdPriceFeed);
        uniswapV3Pool = IUniswapV3Pool(_uniswapV3Pool);
        useChainlink = _useChainlink;
        aegToken = _aegToken;
        wAegToken = _wAegToken;
        // usdcToken = _usdcToken;
        // usdtToken = _usdtToken;
        cards = _cards;
        ethernals = _ethernals;
        adventurers = _adventurers;
        emotes = _emotes;
        cardBacks = _cardBacks;
        paymentReceiver = msg.sender;
        roles[OWNER][msg.sender] = true;
        roles[ADMIN][msg.sender] = true;
    }

    function convertAssets(
        address _assetAddress,
        address _userAddress,
        address _paymentToken,
        uint256[] memory _ids, // types (IG ID NOT TOKEN ID)
        uint256[] memory _amounts,
        uint256 _price, // (ex. 45 = $0.045, 500 = $0.5, 1000 = $1, 10000 = $10) //SEND CALCULATED PRICE
        bool _sb
    ) external onlyRole(ADMIN) whenNotPaused {
        require(_ids.length == _amounts.length, "Invalid input");

        //check that the address is one of the four
        require(
            _assetAddress == cards ||
                _assetAddress == ethernals ||
                _assetAddress == adventurers ||
                _assetAddress == emotes ||
                _assetAddress == cardBacks,
            "Invalid asset address"
        );

        uint256 aegUsdPrice = getAegUsdPrice();
        require(aegUsdPrice > 0, "AEG/USD price is zero");
        uint256 scaledPrice = (_price * 10 ** 33); // Scale _price to 33 decimals because we need to divide by aegUsdPrice which has 18 decimals
        uint256 convertedPrice = scaledPrice / aegUsdPrice;

        require(
            IToken(_paymentToken).balanceOf(_userAddress) >= convertedPrice,
            "Not enough AEG tokens"
        );

        IToken(_paymentToken).transferFrom(
            _userAddress,
            paymentReceiver,
            convertedPrice
        );

        for (uint256 i = 0; i < _ids.length; i++) {
            _convertAsset(
                _assetAddress,
                _userAddress,
                _ids[i],
                _amounts[i],
                _sb
            );
        }

        emit ConvertedCards(_assetAddress, _userAddress, _ids, _amounts);
    }

    function _convertAsset(
        address _assetAddress,
        address _userAddress,
        uint256 _type,
        uint256 _amount,
        bool _sb
    ) private {
        if (_assetAddress == cards) {
            (, , bool exists, Library.Rarity rarity, bool isPromo) = ICard(
                _assetAddress
            ).types(_type);

            require(exists, "Invalid type");
            require(!isPromo, "Cannot convert promo assets");
            require(
                rarity != Library.Rarity.Basic,
                "Cannot convert basic assets"
            );
            INft(_assetAddress).adminMint(_userAddress, _type, 1, _amount, _sb);
        } else if (_assetAddress == emotes) {
            (, , bool exists) = IEmote(_assetAddress).types(_type);

            require(exists, "Invalid type");
            IEmote(_assetAddress).adminMint(_userAddress, _type, _amount, _sb);
        } else {
            (, , , bool exists) = INft(_assetAddress).types(_type);

            require(exists, "Invalid type");
            INft(_assetAddress).adminMint(_userAddress, _type, 1, _amount, _sb);
        }
    }

    // ONLY FOR TESTING ----------------------------
    uint160 constant testPrice = 177099116423414427175393512050595101; // about $0.20
    function getAegUsdPrice() public pure returns (uint256) {
        uint160 sqrtPriceX96 = testPrice;
        uint256 price = 1e42 /
            (((uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (2 ** 192)) *
                1e12);

        console.log("price: ", price);

        console.log(
            "test calc of 1000 or $1 purchase: ",
            (1000 * 10 ** 33) / price
        );

        return price; //invert price with increased precision
    }

    // PROD ----------------------------

    // function getAegUsdPrice() public view returns (uint256) {
    //     (uint160 sqrtPriceX96, , , , , , ) = uniswapV3Pool.slot0();
    //     return
    //         1e42 /
    //         (((uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (2 ** 192)) *
    //             1e12);
    // }

    // WEB2 PAYMENT ----------------------------

    event PurchaseMade(
        address indexed _userAddress,
        address indexed _paymentToken,
        uint256 _acAmount,
        uint256 _price,
        uint256 _usdPrice
    );
    address public usdcToken;
    address public usdtToken;

    mapping(uint256 => uint256) public purchaseOptions; //ac amount => usd price

    function purchaseAC(
        uint256 purchaseOption,
        address paymentAddress
    ) external {
        require(purchaseOptions[purchaseOption] > 0, "Invalid purchase option");
        uint256 purchaseUsdPrice = purchaseOptions[purchaseOption];
        IToken paymentToken = IToken(paymentAddress);
        uint256 price;

        if (paymentAddress == aegToken) {
            uint256 aegUsdPrice = getAegUsdPrice();
            price = (purchaseUsdPrice * 10 ** 33) / aegUsdPrice;
        } else {
            //if they are paying instable, the price is 1000 for $1 and stable decimal is 6
            price = purchaseUsdPrice * 1000;
        }

        require(
            paymentToken.balanceOf(msg.sender) >= price,
            "Not enough tokens"
        );

        console.log("price: ", price);

        paymentToken.transferFrom(msg.sender, paymentReceiver, price);

        // Emit the event
        emit PurchaseMade(
            msg.sender,
            paymentAddress,
            purchaseOption,
            price,
            purchaseUsdPrice
        );
    }

    function setPurchaseOption(
        uint256 _acAmount,
        uint256 _usdPrice
    ) external onlyRole(ADMIN) {
        purchaseOptions[_acAmount] = _usdPrice;
    }

    // ----------------------------

    function setUseChainlink(bool _useChainlink) external onlyRole(OWNER) {
        useChainlink = _useChainlink;
    }

    function setUniswapV3Pool(address _uniswapV3Pool) external onlyRole(OWNER) {
        uniswapV3Pool = IUniswapV3Pool(_uniswapV3Pool);
    }

    function setUsdcToken(address _usdcToken) external onlyRole(OWNER) {
        usdcToken = _usdcToken;
    }

    function setUsdtToken(address _usdtToken) external onlyRole(OWNER) {
        usdtToken = _usdtToken;
    }

    function setPaymentReceiver(
        address _paymentReceiver
    ) external onlyRole(OWNER) {
        paymentReceiver = _paymentReceiver;
    }

    // ACCESS CONTROL ----------------------------

    mapping(bytes32 => mapping(address => bool)) public roles;
    bytes32 public constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    bytes32 public constant OWNER = keccak256(abi.encodePacked("OWNER"));

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(roles[role][msg.sender], "Not authorized to converter.");
        _;
    }

    function grantRole(bytes32 role, address account) public onlyRole(OWNER) {
        roles[role][account] = true;
    }

    function revokeRole(bytes32 role, address account) public onlyRole(OWNER) {
        roles[role][account] = false;
    }

    function transferOwnership(address newOwner) external onlyRole(OWNER) {
        grantRole(OWNER, newOwner);
        grantRole(ADMIN, newOwner);
        revokeRole(OWNER, msg.sender);
        revokeRole(ADMIN, msg.sender);
        paymentReceiver = newOwner;
    }
}

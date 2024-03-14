// SPDX-License-Identifier: MIT

// solhint-disable-next-line
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IToken.sol";
// import "./Library.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts-upgradeable-4.7.3/proxy/utils/Initializable.sol";

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
        cards = _cards;
        ethernals = _ethernals;
        adventurers = _adventurers;
        emotes = _emotes;
        cardBacks = _cardBacks;
        paymentReceiver = msg.sender;
        roles[OWNER][msg.sender] = true;
        roles[ADMIN][msg.sender] = true;
    }

    // function that takes and asset address, useraddress, payment token, array of ids, array of amounts and sb(boolean for if its osulbound or not)
    // check that the asset address is one of the 5 allowed addresses
    // take the price that comes in as dollars (45 = $0.045, 500 = $0.5, etc.) and convert it to AEG price
    // check to see if msg.sender has the required amount of payment token
    // transfer the payment token from msg.sender to the payment receiver
    // check the given asset address and check if the items exist with contract.types(type)
    //check if any of the items isPromo, if they are, revert
    // check if the items are basic(Rarity.Basic), if they are, revert NEED TO MAKE RARITY ENUM
    //use NFTInterface to adminMint(userAddress, type, 1, amount,sb)
    // function convertAssets

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

        console.log("price: %s", _price);
        uint256 aegUsdPrice = getAegUsdPrice(18);
        require(aegUsdPrice > 0, "AEG/USD price is zero");
        uint256 scaledPrice = (_price * 10 ** 15); // Scale _price to 15 decimals because AEG has 18 decimals and we get our price with 3 decimal places
        uint256 convertedPrice = scaledPrice / aegUsdPrice;

        console.log("convertedPrice: %s", convertedPrice);

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
        console.log("type: %s", _type);
        if (_assetAddress == cards) {
            (, , bool exists, Library.Rarity rarity, bool isPromo) = ICard(
                _assetAddress
            ).types(_type);

            console.log("exists: ", exists);
            console.log("isPromo: ", isPromo);

            require(exists, "Invalid type");
            require(!isPromo, "Cannot convert promo assets");
            require(
                rarity != Library.Rarity.Basic,
                "Cannot convert basic assets"
            );
            INft(_assetAddress).adminMint(_userAddress, _type, 1, _amount, _sb);
        } else if (_assetAddress == emotes) {
            (, , bool exists) = IEmote(_assetAddress).types(_type);

            console.log("exists: ", exists);
            require(exists, "Invalid type");
            IEmote(_assetAddress).adminMint(_userAddress, _type, _amount, _sb);
        } else {
            (, , , bool exists) = INft(_assetAddress).types(_type);

            console.log("exists: ", exists);
            require(exists, "Invalid type");
            INft(_assetAddress).adminMint(_userAddress, _type, 1, _amount, _sb);
        }
    }

    function getAegUsdPrice(
        uint256 targetDecimals
    ) public view returns (uint256) {
        if (useChainlink) {
            (, int256 price, , , ) = aegUsdPriceFeed.latestRoundData();
            require(price > 0, "Invalid price");

            uint256 rawPrice = uint256(price);
            uint256 feedDecimals = aegUsdPriceFeed.decimals();

            if (feedDecimals < targetDecimals) {
                return rawPrice * (10 ** (targetDecimals - feedDecimals));
            } else if (feedDecimals > targetDecimals) {
                return rawPrice / (10 ** (feedDecimals - targetDecimals));
            } else {
                return rawPrice;
            }
        } else {
            (uint160 sqrtPriceX96, , , , , , ) = uniswapV3Pool.slot0();
            return
                ((uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (2 ** 96)) *
                1e12;
        }
    }

    function setUseChainlink(bool _useChainlink) external onlyRole(OWNER) {
        useChainlink = _useChainlink;
    }

    function setUniswapV3Pool(address _uniswapV3Pool) external onlyRole(OWNER) {
        uniswapV3Pool = IUniswapV3Pool(_uniswapV3Pool);
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

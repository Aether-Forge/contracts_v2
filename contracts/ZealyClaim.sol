// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable-4.7.3/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable-4.7.3/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.7.3/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.7.3/utils/cryptography/ECDSAUpgradeable.sol";

enum Rarity {
    Basic,
    Common,
    Uncommon,
    Rare,
    Epic,
    Legendary
}

interface ICard {
    function getRarityToCardTypes(
        Rarity rarity
    ) external view returns (uint256[] memory);
    function adminMint(address, uint256, uint256, uint256, bool) external;
}

contract ZealyClaim is Initializable, ReentrancyGuardUpgradeable {
    struct Allocation {
        uint256 amount;
        uint256 rarity;
    }

    IERC20Upgradeable public token;
    ICard public nft;
    address public owner;
    bool public paused;

    mapping(address => Allocation) public allocations;

    event Claimed(address indexed user, uint256 amount, uint256 rarity);

    function initialize(address _token, address _nft) public initializer {
        token = IERC20Upgradeable(_token);
        nft = ICard(_nft);
        owner = msg.sender;
        __ReentrancyGuard_init();
    }

    function claim() public nonReentrant {
        require(!paused, "Claiming is paused");
        Allocation storage allocation = allocations[msg.sender];
        require(allocation.amount > 0, "Nothing left to claim");

        if (allocation.rarity > 0) {
            uint256[] memory cardTypes = nft.getRarityToCardTypes(
                getRarityFromValue(allocation.rarity)
            );

            uint256 randomIndex = uint256(
                keccak256(abi.encodePacked(block.timestamp))
            ) % cardTypes.length;

            nft.adminMint(msg.sender, cardTypes[randomIndex], 1, 1, false);

            allocation.rarity = 0;
        }

        token.transfer(msg.sender, allocation.amount);
        emit Claimed(msg.sender, allocation.amount, allocation.rarity);

        allocation.amount = 0;
    }

    function getRarityFromValue(uint value) public pure returns (Rarity) {
        return Rarity(value);
    }

    function isValidSignature(
        address account,
        bytes memory signature
    ) public returns (bool) {
        // This is the message that your backend should sign
        bytes32 message = keccak256(abi.encodePacked(account));

        // This is the account that should have signed the message
        address expectedSigner = owner; // could use a diff wallet instead of owner

        // Recover the signer from the signature
        address recoveredSigner = ECDSAUpgradeable.recover(message, signature);

        // The signature is valid if the recovered signer is the expected signer
        return recoveredSigner == expectedSigner;
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function setAllocation(
        address _address,
        uint256 _amount,
        uint256 _rarity
    ) public onlyOwner {
        allocations[_address] = Allocation(_amount, _rarity);
    }

    function setAllocations(
        address[] memory _addresses,
        uint256[] memory _amounts,
        uint256[] memory _rarities
    ) public onlyOwner {
        require(
            _addresses.length == _amounts.length &&
                _addresses.length == _rarities.length,
            "Arrays must be the same length"
        );

        for (uint256 i = 0; i < _addresses.length; i++) {
            allocations[_addresses[i]] = Allocation(_amounts[i], _rarities[i]);
        }
    }

    function allocationOf(
        address _address
    ) public view returns (uint256, uint256) {
        return (allocations[_address].amount, allocations[_address].rarity);
    }

    function withdraw(uint256 _amount) public onlyOwner {
        token.transfer(owner, _amount);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
}

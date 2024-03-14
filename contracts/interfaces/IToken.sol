// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import "../libraries/Library.sol";

interface IToken {
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external;
}

interface ICard {
    function types(
        uint256 _id
    )
        external
        view
        returns (string memory, uint256, bool, Library.Rarity, bool);
}

interface INft {
    function adminMint(
        address _to,
        uint256 _type,
        uint256 _level,
        uint256 _amount,
        bool _sb
    ) external;

    function ownerOf(uint256) external view returns (address);

    function totalTypes() external view returns (uint256);

    function types(
        uint256 _id
    ) external view returns (string memory, uint256, Library.Rarity, bool);
}

interface IEmote {
    function types(
        uint256 _id
    ) external view returns (string memory, uint256, bool);

    function adminMint(
        address _to,
        uint256 _type,
        uint256 _amount,
        bool _sb
    ) external;
}

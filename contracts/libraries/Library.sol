// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.19;

library Library {
    enum Rarity {
        Basic,
        Common,
        Uncommon,
        Rare,
        Epic,
        Legendary
    }

    struct Type {
        string uri;
        uint256 currentSupply;
        bool exists;
        Library.Rarity rarity;
        bool isPromo;
    }
}

const { ethers } = require("hardhat")
const { MerkleTree } = require("merkletreejs")
const keccak256 = require("keccak256")

// The claims are pairs of address and amount
const claims = [
  { address: "0x...", amount: 100 },
  { address: "0x...", amount: 200 },
  // ...
]

// Hash the claims into leaf nodes
const leaves = claims.map((claim) => keccak256(abiEncodeClaim(claim)))

// Create the Merkle tree
const tree = new MerkleTree(leaves, keccak256)

// Get the Merkle root
const root = tree.getRoot().toString("hex")

console.log(root)

function abiEncodeClaim(claim) {
  // This function should ABI encode the claim into a format that matches the one used in the smart contract
  // For example, if the smart contract uses `keccak256(abi.encodePacked(msg.sender, amount))`, this function should return `ethers.utils.solidityKeccak256(['address', 'uint256'], [claim.address, claim.amount])`
  return ethers.utils.solidityKeccak256(["address", "uint256"], [claim.address, claim.amount])
}

const { network } = require("hardhat")

function getNetworkContracts() {
  // console.log("network.name in getnetworkcontracts", network.name)
  return {
    AEG_TOKEN,
    WAEG_TOKEN,
    CARDS,
    ETHERNALS,
    ADVENTURERS,
    EMOTES,
    CARD_BACKS,
    AEG_USD_CHAINLINK,
    UNISWAP_V3_POOL,
  }
}

const AEG_TOKEN = {
  address:
    network.name === "mumbai"
      ? "0x6866E9BDaF921050302680537DeFe9E17352F780"
      : "0xfdA426b79B27e5ee806c287f5EC28086D43f2721",
}

const WAEG_TOKEN = {
  address:
    network.name === "mumbai"
      ? "0x869A2D7CA9a291A7A28A5F6EF4151180716675dA"
      : "0xfdA426b79B27e5ee806c287f5EC28086D43f2721",
}

const CARDS = {
  address:
    network.name === "mumbai"
      ? "0x930574f4d25f7C67aB021384727D81ab0d8baC17"
      : "0xA271d8A51170884bFCE12c2Bbc5c7B4047d9f725",
}

const ETHERNALS = {
  address:
    network.name === "mumbai"
      ? "0x0bE149685145D11B90a7Cb325E5526Ed2767c0bf"
      : "0xBc39f898f1F9678E69Ec0d3AC6674D331F6A7A8c",
}

const ADVENTURERS = {
  address:
    network.name === "mumbai"
      ? "0x58f0E4F5838AD7Ecc9a4d2ae791bB1220F21dA49"
      : "0x6b44232BD0cCB3A1ac3587464069629cbdEFBF28",
}

const EMOTES = {
  address:
    network.name === "mumbai"
      ? "0xeAf07D5271a686f94d1223B71b5cbF50aCAa868e"
      : "0x9bF4689E07831bA85199e259a8b6A68C7F112c04",
}

const CARD_BACKS = {
  address:
    network.name === "mumbai"
      ? "0x33E7AA53b6cbE0B4D3D14cC885D867DC58E087A7"
      : "0x7ca5F906bf2891142c749c043E1Ee43429D43BeA",
}

const AEG_USD_CHAINLINK = {
  address:
    network.name === "mumbai"
      ? "0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0" //this is usdc pricefeed for testing
      : "0xfdA426b79B27e5ee806c287f5EC28086D43f2721",
}

const UNISWAP_V3_POOL = {
  address:
    network.name === "mumbai"
      ? "0xfdA426b79B27e5ee806c287f5EC28086D43f2721"
      : "0x53e9a5490Bc6eB0f8A6338E85955F84484672571",
}

module.exports = {
  getNetworkContracts,
}

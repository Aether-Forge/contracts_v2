const { ethers, upgrades, network, run } = require("hardhat")
const fs = require("fs")
const { getNetworkContracts } = require("../utils/CONSTANTS")

async function main() {
  console.log("Deploying COEConverter_V2...", network.name)
  const COEConverter = await ethers.getContractFactory("COEConverter_V2")

  // console.log("aeg token", AEG_TOKEN)

  const contracts = getNetworkContracts()

  console.log("contracts", contracts)

  //if network is mumbai or polygon use the following addresses
  const args = [
    contracts.AEG_TOKEN.address,
    contracts.WAEG_TOKEN.address,
    contracts.CARDS.address,
    contracts.ETHERNALS.address,
    contracts.ADVENTURERS.address,
    contracts.EMOTES.address,
    contracts.CARD_BACKS.address,
    contracts.AEG_USD_CHAINLINK.address,
    contracts.UNISWAP_V3_POOL.address,
    true,
  ]

  const converter = await upgrades.deployProxy(COEConverter, args)

  await converter.waitForDeployment()
  const proxyAddress = await converter.getAddress()
  // const implementationAddress = await ethers.provider.getStorageAt(
  //   proxyAddress,
  //   "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
  // )

  console.log(`Converter_V2 deployed to: ${proxyAddress}`)
  // console.log(`Implementation contract at: ${implementationAddress}`)

  // Create deployments directory if it doesn't exist
  if (!fs.existsSync("./deployments")) {
    fs.mkdirSync("./deployments")
  }

  // Check if the file already exists
  const filePath = `./deployments/${network.name}.json`
  let data = {
    contract: "COEConverter_V2",
    proxyAddress,
    // implementationAddress,
  }

  if (fs.existsSync(filePath)) {
    // If file exists, read the file and update the data
    const fileData = JSON.parse(fs.readFileSync(filePath, "utf8"))
    data = { ...fileData, ...data }
  }

  // Write the contract name and address to the deployments directory
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })

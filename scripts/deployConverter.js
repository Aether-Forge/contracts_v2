const { ethers, upgrades, network, run } = require("hardhat")
const fs = require("fs")
const { getNetworkContracts } = require("../utils/networkContracts.util")

const ADMIN_ROLE = "0xdf8b4c520ffe197c5343c6f5aec59570151ef9a492f2c624fd45ddde6135ec42"

async function main() {
  let usdcTokenAddress, usdTTokenAddress, testTokenStable
  console.log("Deploying COEConverter_V2...", network.name)
  const COEConverter = await ethers.getContractFactory("COEConverter_V2")

  // console.log("aeg token", AEG_TOKEN)

  const contracts = getNetworkContracts()

  console.log("contracts", contracts)

  //if network is mumbai or polygon use the following addresses
  const args = [
    contracts.AEG_TOKEN.address,
    contracts.WAEG_TOKEN.address,
    // contracts.USDC_TOKEN.address,
    // contracts.USDT_TOKEN.address,
    contracts.CARDS.address,
    contracts.ETHERNALS.address,
    contracts.ADVENTURERS.address,
    contracts.EMOTES.address,
    contracts.CARD_BACKS.address,
    contracts.AEG_USD_CHAINLINK.address,
    contracts.UNISWAP_V3_POOL.address,
    false,
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

  console.log("------------------Setup ------------------")
  console.log("Granting roles to the converter")

  const [owner] = await ethers.getSigners()

  const abi = ["function grantRole(bytes32 role, address account)"]

  const contractsToGrant = [
    new ethers.Contract(contracts.CARDS.address, abi, owner),
    new ethers.Contract(contracts.ETHERNALS.address, abi, owner),
    new ethers.Contract(contracts.ADVENTURERS.address, abi, owner),
    new ethers.Contract(contracts.EMOTES.address, abi, owner),
    new ethers.Contract(contracts.CARD_BACKS.address, abi, owner),
  ]

  for (let i = 0; i < contractsToGrant.length; i++) {
    const contract = contractsToGrant[i]
    //use ethers to send the transaction
    const response = await contract.grantRole(ADMIN_ROLE, proxyAddress)
    //wait for the transaction to be mined
    await response.wait()

    console.log(`Role granted`, response.hash)
  }

  //--------------------set up the ac purchse options-----
  console.log("Setting up purchase options")

  await converter.setUsdcToken(contracts.USDC_TOKEN.address)
  await converter.setUsdtToken(contracts.USDT_TOKEN.address)

  //1000 ac for 2500 amount, 2100 for 5000, 4400 for 10000, 9000 for 20000, 23200 for 50000, 50000 for 100000
  const purchaseOptions = [
    { usdPrice: 2500, ac: 1000 },
    { usdPrice: 5000, ac: 2100 },
    { usdPrice: 10000, ac: 4400 },
    { usdPrice: 20000, ac: 9000 },
    { usdPrice: 50000, ac: 23200 },
    { usdPrice: 100000, ac: 50000 },
  ]

  for (let i = 0; i < purchaseOptions.length; i++) {
    const option = purchaseOptions[i]
    const response = await converter.setPurchaseOption(option.ac, option.usdPrice)
    await response.wait()
    console.log(`Purchase option set`, response.hash)
  }

  //--------------------local testing---------------------

  if (network.name === "localhost" || network.name === "hardhat") {
    console.log("running local tests")

    //get getAegUsdPrice
    const aegUsdPrice = await converter.getAegUsdPrice()
    console.log("aegUsdPrice", aegUsdPrice.toString())

    const TestTokenStable = await ethers.getContractFactory("TestTokenStable")
    testTokenStable = await TestTokenStable.deploy()
    await testTokenStable.waitForDeployment()
    const usdcTokenAddress = await testTokenStable.getAddress()
    const usdTTokenAddress = await testTokenStable.getAddress()

    await converter.setUsdcToken(usdcTokenAddress)
    await converter.setUsdtToken(usdTTokenAddress)

    //need to test the purchaseAC function
    //approve
    const approve = await testTokenStable.approve(proxyAddress, ethers.parseEther("10000"))
    await approve.wait()

    const purchaseAC = await converter.purchaseAC(1000, usdcTokenAddress)
    await purchaseAC.wait()
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })

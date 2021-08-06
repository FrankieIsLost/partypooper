const hre = require("hardhat");
const fs = require("fs");
const path = require('path');


async function main() {
    
    const aaveLendingPoolAddress = "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5";
    
    const [deployer] = await ethers.getSigners();
    console.log(
      "Deploying the contracts with the account:",
      await deployer.getAddress()
    );
  
    console.log("Account balance before deploy:", (await deployer.getBalance()).toString());
  
    const PartyPooper = await hre.ethers.getContractFactory("PartyPooper");
    const partypooper = await PartyPooper.deploy(aaveLendingPoolAddress, {gasLimit: 2000000});

    await partypooper.deployed();
  
    console.log("Partypooper address:", partypooper.address);
    console.log("Account balance after deploy:", (await deployer.getBalance()).toString());
  
    const deployInfo = {
      network: hre.network.name,
      addresses: {
        partyPoopeerAddress: partypooper.address,
        aaveLendingPoolAddress: aaveLendingPoolAddress
      }
    };
    const directory = path.resolve(__dirname, "../deploy-info");
    const filename = `${directory}/${hre.network.name}.json`;

    if (!fs.existsSync(directory)) {
      fs.mkdirSync(directory,  { recursive: true });
    }

    fs.writeFileSync(
        filename,
        JSON.stringify(deployInfo, null, 2),
    );
    console.log(`Addresses written to ${filename}`);
  }
  
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
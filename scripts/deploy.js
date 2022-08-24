const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require('fs');
const path = require('path');

async function main() {
  const [owner] = await ethers.getSigners()

  const AMMRouter = await ethers.getContractFactory("AMMRouter", owner)
  const router = await AMMRouter.deploy()
  await router.deployed()

  const AMMStaking = await ethers.getContractFactory("AMMStaking", owner)
  const stakingManager = await AMMStaking.deploy()
  await stakingManager.deployed()


  console.log("AMMRouter deployed successfully:", router.address)
  console.log("AMMStaking deployed successfully:", stakingManager.address)

  saveFrontendFiles({
    AMMRouter: router,
    AMMStaking: stakingManager
  })
}


function saveFrontendFiles(contracts) {
  const contractsDir = path.join(__dirname, '/..', 'src/contracts')

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir)
  }

  Object.entries(contracts).forEach((contractItem) => {
    const [name, contract] = contractItem

    if (contract) {
      fs.writeFileSync(
        path.join(contractsDir, '/', name + '-contract-address.json'),
        JSON.stringify({[name]: contract.address}, undefined, 2)
      )
    }

    const ContractArtifact = hre.artifacts.readArtifactSync(name)

    fs.writeFileSync(
      path.join(contractsDir, '/', name + ".json"),
      JSON.stringify(ContractArtifact, null, 2)
    )

  })

}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});

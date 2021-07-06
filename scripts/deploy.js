// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const PotluckSettings = await hre.ethers.getContractFactory("PotluckSettings");
  const settings = await PotluckSettings.deploy(
    10,
    60 * 60 * 24 * 3,
    60 * 15,
    60 * 15,
    hre.ethers.utils.parseEther("1000"),
    hre.ethers.utils.parseEther("500"),
    100
  );
  await settings.deployed();
  console.log("Potluck Settings deployed to:", settings.address);

  // We get the contract to deploy
  const PotluckFactory = await hre.ethers.getContractFactory("PotluckFactory");
  const factory = await PotluckFactory.deploy(settings.address);
  await factory.deployed();
  console.log("Potluck Factory deployed to:", factory.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

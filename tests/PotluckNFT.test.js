const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("PotluckNFT", function() {
  it("Should return the new greeting once it's changed", async function() {
    const Greeter = await ethers.getContractFactory("Greeter");
    const greeter = await Greeter.deploy("Hello, world!");

    await greeter.deployed();
    expect(await greeter.greet()).to.equal("Hello, world!");

    await greeter.setGreeting("Hola, mundo!");
    expect(await greeter.greet()).to.equal("Hola, mundo!");
  });

  // can create
  // can contribute
  // can withdraw
  // cannot contribute after withdrawing
  // cannot contribute past max
  // can claim nft
  // can update reserve price
  // can send eth to commence auction
  // can bid
  // can update bid
  // can end auction
  // can claim proceeds
});

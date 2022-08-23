const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AMMFactory", () => {
  let mainAccount
  let contract
  let token0
  let token1

  beforeEach(async () => {
    [mainAccount] = await ethers.getSigners()

    // library deployment
    const AMMMath = await ethers.getContractFactory("AMMMath", mainAccount)
    const library = await AMMMath.deploy()
    await library.deployed()

    // Contract factory for AMMFactory
    const AMMFactory = await ethers.getContractFactory("AMMFactory", {
      signer: mainAccount,
      libraries: {
        AMMMath: library.address,
      },
    })
    
    // contract deployment
    contract = await AMMFactory.deploy()
    await contract.deployed()
    
    // Contract factory for ERC20 tokens
    const ERC20 = await ethers.getContractFactory("Token", mainAccount)
    
    // Deployment of token0 and token1
    token0 = await ERC20.deploy("TestToken0", "TKN0", 100)
    await token0.deployed()

    token1 = await ERC20.deploy("TestToken1", "TKN1", 100)
    await token1.deployed()
    
  })

  describe("Modifier properAddress", () => {
    it("shouldn't allow adding tokens with zero address", async () => {
      await expect(
        contract.addPair(token0.address, ethers.constants.AddressZero)
      ).to.be.revertedWith("AMMFactory: zero address")
      
      await expect(
        contract.getAddressPair(ethers.constants.AddressZero, token1.address)
      ).to.be.revertedWith("AMMFactory: zero address")
        
    })
      
    it("shouldn't allow adding a pair of two identical tokens", async () => {
      await expect(
        contract.addPair(token0.address, token0.address)
      ).to.be.revertedWith("AMMFactory: identical tokens")
      
      await expect(
        contract.getAddressPair(token1.address, token1.address)
      ).to.be.revertedWith("AMMFactory: identical tokens")
  
    })
  })

  describe("getAddressPair", () => {
    it("should return the correct address for an existing pair", async () => {
      const pairAddress = await contract.callStatic.addPair(token0.address, token1.address)
      await contract.addPair(token0.address, token1.address)

      expect(
        await contract.getAddressPair(token0.address, token1.address)
      ).to.equal(
        pairAddress
      )
    })

    it("should return zero address if pair doesn't exist", async () => {
      expect(
        await contract.getAddressPair(token0.address, token1.address)
      ).to.equal(ethers.constants.AddressZero)
    })
    
  })

  describe("addPair", () => {
    it("should add a new token pair", async () => {
      const pairAddress = await contract.callStatic.addPair(token0.address, token1.address)
      await contract.addPair(token0.address, token1.address)

      // direct and swaped addresses should give the same pair address
      expect(
        await contract.getAddressPair(token0.address, token1.address)
      ).to.equal(
        pairAddress
      )

      expect(
        await contract.getAddressPair(token1.address, token0.address)
      ).to.equal(
        pairAddress
      )

    })
    
    it("should revert if pair already exists", async () => {
      await contract.addPair(token0.address, token1.address)

      await expect(
        contract.addPair(token1.address, token0.address)
      ).to.be.revertedWith("AMMFactory: pair already exists")
  
      await expect(
        contract.addPair(token0.address, token1.address)
      ).to.be.revertedWith("AMMFactory: pair already exists")

    })

    it("should emit an event", async () => {
      await expect(contract.addPair(token0.address, token1.address))
        .to.emit(contract, 'AddPair')
        .withArgs(
          token0.address, 
          token1.address, 
          await contract.callStatic.getAddressPair(token0.address, token1.address)
        )
    })
  })
})
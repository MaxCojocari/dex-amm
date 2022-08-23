const { expect } = require("chai");
const { ethers } = require("hardhat");
const poolJSON = require("../artifacts/contracts/AMMPair.sol/AMMPair.json");

describe("AMMRouter", () => {
  let signer
  let account
  let router
  let factory
  let factoryETH
  let pool
  let poolETH
  let token0
  let token1

  beforeEach(async () => {
    [signer, account] = await ethers.getSigners()

    const AMMMath = await ethers.getContractFactory("AMMMath", signer)
    const library = await AMMMath.deploy()
    await library.deployed()

    // Contract factory for AMMRouter and AMMFactory
    const AMMRouter = await ethers.getContractFactory("AMMRouter", signer)

    const AMMFactory = await ethers.getContractFactory("AMMFactory", {
      signer: signer,
      libraries: {
        AMMMath: library.address,
      },
    })

    const AMMFactoryETH = await ethers.getContractFactory("AMMFactoryETH", {
      signer: signer,
      libraries: {
        AMMMath: library.address,
      },
    })

    // factory contract deployment
    factory = await AMMFactory.deploy()
    await factory.deployed()

    // factory ETH-token contract deployment
    factoryETH = await AMMFactoryETH.deploy()
    await factory.deployed()

    // router contract deployment (for token-token pools)
    router = await AMMRouter.deploy(factory.address, factoryETH.address)
    await router.deployed()

    // Contract factory for ERC20 tokens
    const ERC20 = await ethers.getContractFactory("Token", signer)

    // token0 and token1 contract deployment
    token0 = await ERC20.deploy("TestToken0", "TKN0", 1e+9)
    await token0.deployed()

    token1 = await ERC20.deploy("TestToken1", "TKN1", 1e+9)
    await token1.deployed()

  })


  describe("createPool", () => {
    it("should revert if pair already exists", async () => {
      await router.createPool(token0.address, token1.address)

      // even though the pair is reversed, its address should be the same
      // as for initial case
      await expect(
        router.createPool(token1.address, token0.address)
      ).to.be.revertedWith("AMMRouter: pair already exists");
    })

    it("should create a new pool if it doesn't exist", async () => {
      const newPair = await router.callStatic.createPool(token0.address, token1.address)
      await router.createPool(token0.address, token1.address)

      const pairReceived = await factory.callStatic.getAddressPair(token0.address, token1.address)

      expect(newPair).to.equal(pairReceived)
    })
  })

  describe("createPoolETH", () => {
    it("should revert if pair already exists", async () => {
      await router.createPoolETH(token0.address)

      await expect(
        router.createPoolETH(token0.address)
      ).to.be.revertedWith("AMMRouter: pair already exists");
    })

    it("should create a new pool if it doesn't exist", async () => {
      const newPair = await router.callStatic.createPoolETH(token1.address)
      await router.createPoolETH(token1.address)

      const pairReceived = await factoryETH.callStatic.getAddressPair(token1.address)

      expect(newPair).to.equal(pairReceived)
    })
  })

  describe("getPair", () => {
    it("should get the correct address of pair", async () => {
      const newPair = await router.callStatic.createPool(token0.address, token1.address)
      await router.createPool(token0.address, token1.address)

      const pair = await router.callStatic.getPair(token0.address, token1.address)

      expect(newPair).to.equal(pair)
    })
  })

  describe("getPairETH", () => {
    it("should get the correct address of pair", async () => {
      const newPair = await router.callStatic.createPoolETH(token0.address)
      await router.createPoolETH(token0.address)

      const pair = await router.callStatic.getPairETH(token0.address)

      expect(newPair).to.equal(pair)
    })
  })

  const initSetup = async () => {
    pool = await router.callStatic.createPool(token0.address, token1.address)
    await router.createPool(token0.address, token1.address)

    poolETH = await router.callStatic.createPoolETH(token0.address)
    await router.createPoolETH(token0.address)

    await token0.approve(pool, 1e+9)
    await token0.approve(poolETH, 1e+9)
    await token1.approve(pool, 1e+9)
    await token1.approve(poolETH, 1e+9)
  }

  describe("addLiquidity", () => {
    it("should add liquidity to a specified pool", async () => {
      await initSetup()

      // genesis of liquidity
      // check for output resuts
      let output = await router.callStatic.addLiquidity(
        token0.address,
        token1.address,
        2000,
        40000
      )

      expect(output.amount0In.toNumber()).to.equal(2000)
      expect(output.amount1In.toNumber()).to.equal(40000)
      expect(output.LPTokensMinted.toNumber()).to.equal(8944)
    })
  })

  describe("addLiquidityETH", () => {
    it("should add liquidity to a specified pool", async () => {
      await initSetup()

      // genesis of liquidity
      // check for output resuts
      let output = await router.callStatic.addLiquidityETH(
        token0.address,
        2000,
        { value: 40000 }
      )

      expect(output.amountTokenIn.toNumber()).to.equal(2000)
      expect(output.amountETHIn.toNumber()).to.equal(40000)
      expect(output.LPTokensMinted.toNumber()).to.equal(8944)
    })
  })


  describe("removeLiquidity", () => {
    it("should remove liquidity from provided pool", async () => {
      await initSetup()

      // genesis of liquidity
      await router.addLiquidity(
        token0.address,
        token1.address,
        2000,
        8000
      ) // 4000 LP

      // liquidity removal
      const output = await router.callStatic.removeLiquidity(
        token0.address,
        token1.address,
        2000
      )

      expect(output.amount0Out.toNumber()).to.equal(1000)
      expect(output.amount1Out.toNumber()).to.equal(4000)
    })
  })

  describe("removeLiquidityETH", () => {
    it("should remove liquidity from provided pool", async () => {
      await initSetup()

      // genesis of liquidity
      await router.addLiquidityETH(
        token0.address,
        2000,
        { value: 8000 }
      ) // 4000 LP

      // liquidity removal
      const output = await router.callStatic.removeLiquidityETH(
        token0.address,
        2000
      )

      expect(output.amountTokenOut.toNumber()).to.equal(1000)
      expect(output.amountETHOut.toNumber()).to.equal(4000)
    })
  })

  describe("swap", () => {
    it("should allow to swap one token for another and vice-versa", async () => {
      await initSetup()

      // genesis of liquidity
      await router.addLiquidity(
        token0.address,
        token1.address,
        300,
        2700
      )

      await token0.connect(account).approve(pool, 1e+6)
      await token1.connect(account).approve(pool, 1e+6)
      await token0.transfer(account.address, 100)
      await token1.transfer(account.address, 100)

      let output = await (router.connect(account)).callStatic.swap(
        token0.address,
        token1.address,
        token0.address,
        10,
        token0.address
      )

      expect(output.amountIn.toNumber()).to.equal(9)
      expect(output.amountOut.toNumber()).to.equal(78)

      output = await (router.connect(account)).callStatic.swap(
        token1.address,
        token0.address,
        token1.address,
        100,
        token0.address
      )

      expect(output.amountIn.toNumber()).to.equal(100)
      expect(output.amountOut.toNumber()).to.equal(9)
    })
  })

  describe("swapETHForToken", () => {
    it("should allow to swap ETH for token", async () => {
      await initSetup()

      // genesis of liquidity
      await router.addLiquidityETH(
        token0.address,
        300,
        { value: 2700 }
      )

      await token0.connect(account).approve(poolETH, 1e+6)

      output = await (router.connect(account)).callStatic.swapETHForToken(
        token0.address,
        true,
        { value: 100 }
      )

      expect(output.toNumber()).to.equal(10)

      output = await (router.connect(account)).callStatic.swapETHForToken(
        token0.address,
        false,
        { value: 100 }
      )

      expect(output.toNumber()).to.equal(9)
    })
  })

  describe("swapTokenForETH", () => {
    it("should allow to swap token for ETH", async () => {
      await initSetup()

      // genesis of liquidity
      await router.addLiquidityETH(
        token0.address,
        300,
        { value: 2700 }
      )

      await token0.connect(account).approve(poolETH, 1e+6)
      await token0.transfer(account.address, 1000)

      output = await (router.connect(account)).callStatic.swapTokenForETH(
        token0.address,
        1000,
        true
      )
      expect(output.toNumber()).to.equal(2069)

      output = await (router.connect(account)).callStatic.swapTokenForETH(
        token0.address,
        1000,
        false
      )

      expect(output.toNumber()).to.equal(2075)
    })
  })

  describe("sendLiquidity", () => {
    it("should send liqudity to the specified account", async () => {
      pool = await router.callStatic.createPool(token0.address, token1.address)
      const pair = new ethers.Contract(pool, poolJSON.abi, signer)

      await router.createPool(token0.address, token1.address)

      pair.approve(pair.address, 1e+6)
      await token0.approve(pair.address, 1e+6)
      await token1.approve(pair.address, 1e+6)

      await router.addLiquidity(
        token0.address,
        token1.address,
        100,
        100
      )

      const output = await router.callStatic.sendLiquidity(
        token0.address,
        token1.address,
        75,
        account.address
      )

      expect(output).to.be.true
    })
  })

  describe("sendLiquidityETH", () => {
    it("should send liqudity to the specified account", async () => {
      pool = await router.callStatic.createPoolETH(token0.address)
      const pair = new ethers.Contract(pool, poolJSON.abi, signer)

      await router.createPoolETH(token0.address)

      pair.approve(pair.address, 1e+6)
      await token0.approve(pair.address, 1e+6)
      await token1.approve(pair.address, 1e+6)

      await router.addLiquidityETH(
        token0.address,
        100,
        { value: 100 }
      )

      const output = await router.callStatic.sendLiquidityETH(
        token0.address,
        75,
        account.address
      )

      expect(output).to.be.true
    })
  })

  describe("getPrice", () => {
    it("should give the current exchange price of token", async () => {
      await initSetup()

      await router.addLiquidity(
        token0.address,
        token1.address,
        5000,
        9999
      )

      expect(
        (await router.getPrice(
          token0.address,
          token1.address,
          token0.address,
        )
        ).toNumber() / 1e+9
      ).to.equal(1.9998)

      expect(
        (await router.getPrice(
          token0.address,
          token1.address,
          token1.address,
        )
        ).toNumber() / 1e+9
      ).to.equal(0.500050005)
    })
  })

  describe("getPriceETH", () => {
    it("should give the current exchange price of token", async () => {
      await initSetup()

      await router.addLiquidityETH(
        token0.address,
        5000,
        { value: 9999 }
      )

      expect(
        (await router.getPriceETH(
          token0.address,
          false
        )
        ).toNumber() / 1e+9
      ).to.equal(1.9998)

      expect(
        (await router.getPriceETH(
          token0.address,
          true
        )
        ).toNumber() / 1e+9
      ).to.equal(0.500050005)

    })
  })


})
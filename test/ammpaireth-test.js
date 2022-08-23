const { expect } = require("chai");
const { ethers } = require("hardhat");
const provider = ethers.provider;

describe("AMMPairETH", () => {
  let pool
  let token
  let account
  let AMMPairETH

  beforeEach(async () => {
    [signer, account] = await ethers.getSigners()

    const AMMMath = await ethers.getContractFactory("AMMMath", signer)
    const library = await AMMMath.deploy()
    await library.deployed()

    const ERC20 = await ethers.getContractFactory("Token", signer)
    token = await ERC20.deploy("TestToken", "TKN", 1e+9)
    await token.deployed()

    AMMPairETH = await ethers.getContractFactory("AMMPairETH", {
      signer: signer,
      libraries: {
        AMMMath: library.address,
      },
    })
    
    pool = await AMMPairETH.deploy(token.address)
    await pool.deployed()

    await token.approve(pool.address, 1e+9)
  })

  describe("constructor", () => {
    it("shouldn't accept zero address", async () => {
      await expect(AMMPairETH.deploy(ethers.constants.AddressZero))
        .to.be.revertedWith("AMMPairETH: zero address")
    })

    it("should set the name and symbol for LP token", async () => {
      expect(await pool.name()).to.equal("LPToken")
      expect(await pool.symbol()).to.equal("LP")
    })
  })

  describe("addLiquidity", () => {
    it("should accept only nonzero amounts", async () => {
      await expect(pool.addLiquidity(0, signer.address, {value: 100}))
        .to.be.revertedWith("AMMPairETH: invalid amount")

        await expect(pool.addLiquidity(1, signer.address, {value: 0}))
        .to.be.revertedWith("AMMPairETH: invalid amount")
    })

    describe("empty pool", () => {
      it("should set correctly initial liquidity", async () => {
        const output = await pool.callStatic.addLiquidity(200, signer.address, {value: 100})
        
        expect(output.amountTokenIn).to.equal(200)
        expect(output.amountETHIn).to.equal(100)
        
        await pool.addLiquidity(200, signer.address, {value: 100})
  
        expect(
          await provider.getBalance(pool.address)
        ).to.equal(100)
  
        expect(
          await token.balanceOf(signer.address)
        ).to.equal(1e+9 - 200)
  
        expect(
          await pool.balanceOf(signer.address)
        ).to.equal(141)
      })
    })

    describe("non-empty pool", () => {
      beforeEach(async () => {
        await pool.addLiquidity(100, signer.address, {value: 3000})
        await token.transfer(account.address, 1e+6)
        await token.connect(account).approve(pool.address, 1e+6)
      })

      it("initial ratio preserved", async () => {
        const output = await pool.callStatic.addLiquidity(20, account.address, {value: 600})

        expect(output.amountTokenIn).to.equal(19)
        expect(output.amountETHIn).to.equal(597)
        
        await pool.connect(account).addLiquidity(20, account.address, {value: 600})
  
        expect(
          await provider.getBalance(pool.address)
        ).to.equal(3600)
  
        expect(
          await token.balanceOf(account.address)
        ).to.equal(1e+6 - 20)
  
        expect(
          await pool.balanceOf(account.address)
        ).to.equal(109)
      })

      it("disproportionate liquidity added", async () => {
        const output = await pool.callStatic.addLiquidity(200, account.address, {value: 600})
        expect(output.amountTokenIn).to.equal(19)
        expect(output.amountETHIn).to.equal(597)
        
        await pool.connect(account).addLiquidity(200, account.address, {value: 600})
  
        expect(
          await provider.getBalance(pool.address)
        ).to.equal(3600)
  
        expect(
          await token.balanceOf(account.address)
        ).to.equal(1e+6 - 200)
        
        // provider is penalised for sending disproportionate liquigity
        // by receiving less LP tokens
        expect(
          await pool.balanceOf(account.address)
        ).to.equal(109)
      })
    })
  })

  describe("removeLiquidity", () => {
    it("should accept only nonzero amounts", async () => {
      await expect(pool.removeLiquidity(0, signer.address))
        .to.be.revertedWith("AMMPairETH: invalid amount")

    })

    it("shouldn't remove more than actual LP token balanace of account", async () => {
      await pool.addLiquidity(100, signer.address, {value: 100}) // 100 LP
      await expect(pool.removeLiquidity(101, signer.address))
        .to.be.revertedWith("AMMPairETH: insuffcient amount of LP tokens")
    })

    it("should remove liquidity correspondingly", async () => {
      await pool.addLiquidity(200, signer.address, {value: 800})
      
      expect(
        await pool.balanceOf(signer.address)
      ).to.equal(400)

      let output = await pool.callStatic.removeLiquidity(200, signer.address)

      expect(output.amountETHOut).to.equal(400)
      expect(output.amountTokenOut).to.equal(100)

      let tx = await pool.removeLiquidity(200, signer.address)
      await tx.wait()
      
      // happy case
      await expect(() => tx)
        .to.changeEtherBalances([pool, signer], [-400, 400]);

      expect(
        await token.balanceOf(signer.address)
      ).to.equal(1e+9 - 100)
      
      expect(
        await pool.balanceOf(signer.address)
      ).to.equal(200)

      await token.transfer(account.address, 1e+6)
      await token.connect(account).approve(pool.address, 1e+6)
      
      await pool.addLiquidity(100, account.address, {value: 300})
      
      expect(
        await pool.balanceOf(account.address)
      ).to.equal(150)
        
      output = await pool.callStatic.removeLiquidity(150, account.address)
        
      expect(output.amountETHOut).to.equal(300)
      expect(output.amountTokenOut).to.equal(85)
        
      tx = await pool.removeLiquidity(150, account.address)
      await tx.wait()
      
      // unhappy case: provider receives back
      // less liquidity (before: token - 100, ETH - 300, after: token - 85, ETH - 300)
      await expect(() => tx)
        .to.changeEtherBalances([pool, account], [-300, 300]);

      expect(
        await token.balanceOf(account.address)
      ).to.equal(1e+6 - 100 + 85)
      
      expect(
        await pool.balanceOf(account.address)
      ).to.equal(0)
    })
  })

  describe("swapETHToToken", () => {
    beforeEach(async () => {
      await pool.addLiquidity(1000, signer.address, {value: 1000})
    })
    
    it("shouldn't accept zero amount", async () => {
      await expect(pool.swapETHForToken(true, signer.address))
        .to.be.revertedWith("AMMPairETH: invalid amount")
    })

    it("should revert if output amount is insufficient", async () => {
      await expect(pool.swapETHForToken(true, signer.address, {value: 1}))
        .to.be.revertedWith("AMMPairETH: insufficient output amount")
    })

    it("choice fee is ETH", async () => {
      const output = await pool.callStatic.swapETHForToken(true, signer.address, {value: 100})
      expect(output).to.equal(90)

      const tx = await pool.swapETHForToken(true, signer.address, {value: 100})
      await tx.wait()

      await expect(() => tx)
        .to.changeEtherBalances([pool, signer], [100, -100]);

      expect(
        await token.balanceOf(signer.address)
      ).to.equal(1e+9 - 1000 + 90)
    })

    it("choice fee is Token", async () => {
      const output = await pool.callStatic.swapETHForToken(false, signer.address, {value: 100})
      expect(output).to.equal(89)

      const tx = await pool.swapETHForToken(false, signer.address, {value: 100})
      await tx.wait()

      await expect(() => tx)
        .to.changeEtherBalances([pool, signer], [100, -100]);

      expect(
        await token.balanceOf(signer.address)
      ).to.equal(1e+9 - 1000 + 89)
    })
  })


  describe("swapETHToToken", () => {
    beforeEach(async () => {
      await pool.addLiquidity(1000, signer.address, {value: 1000})
    })
    
    it("shouldn't accept zero amount", async () => {
      await expect(pool.swapTokenForETH(0, true, signer.address))
        .to.be.revertedWith("AMMPairETH: invalid amount")
    })

    it("should revert if output amount is insufficient", async () => {
      await expect(pool.swapTokenForETH(1, false, signer.address))
      .to.be.revertedWith("AMMPairETH: insufficient output amount")
    })

    it("choice fee is ETH", async () => {
      const output = await pool.callStatic.swapTokenForETH(100, true, signer.address)
      expect(output).to.equal(89)

      const tx = await pool.swapTokenForETH(100, true, signer.address)
      await tx.wait()

      await expect(() => tx)
        .to.changeEtherBalances([pool, signer], [-89, 89]);

      expect(
        await token.balanceOf(signer.address)
      ).to.equal(1e+9 - 1000 - 100) 
    })

    it("choice fee is Token", async () => {
      const output = await pool.callStatic.swapTokenForETH(100, false, signer.address)
      expect(output).to.equal(90)

      const tx = await pool.swapTokenForETH(100, false, signer.address)
      await tx.wait()

      await expect(() => tx)
        .to.changeEtherBalances([pool, signer], [-90, 90]);

      expect(
        await token.balanceOf(signer.address)
      ).to.equal(1e+9 - 1000 - 100)
    })
  })

  describe("getPrice", () => {
    it("should return token's correct price", async () => {
      await pool.addLiquidity(253, signer.address, {value: 1000})
      expect(
        await pool.getPrice(false) / 1e+9
      ).to.equal(3.952569169)
    })

    it("should return eth correct price according to the ratio in pool", async () => {
      await pool.addLiquidity(253, signer.address, {value: 1000})
      expect(
        await pool.getPrice(true) / 1e+9
      ).to.equal(0.253)
    })
  })

  describe("sendLiquidity", async () => {
    it("shouldn't accept zero amount", async () => {
      await expect(pool.sendLiquidity(0, signer.address, account.address))
        .to.be.revertedWith("AMMPairETH: invalid amount")
    })

    it("shouldn't accept zero addresses", async () => {
      await expect(pool.sendLiquidity(10, ethers.constants.AddressZero, account.address))
        .to.be.revertedWith("AMMPairETH: transfer from zero address")

      await expect(pool.sendLiquidity(10, signer.address, ethers.constants.AddressZero))
        .to.be.revertedWith("AMMPairETH: transfer to zero address")
    })

    it("should send LP Tokens", async () => {
      await pool.addLiquidity(1000, signer.address, {value: 1000})
      await pool.approve(pool.address, 1000)
      await expect(
        () => pool.sendLiquidity(200, signer.address, account.address)
      ).to.changeTokenBalances(pool, [signer, account], [-200, 200]);
    })
  })
})

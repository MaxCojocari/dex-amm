const { expect } = require("chai");
const { ethers } = require("hardhat");
const provider = ethers.provider

describe("AMMPair", () => {
  let mainAccount
  let AMMPair
  let account1
  let account2
  let account3
  let token0
  let token1
  let token2
  let pool
  
  beforeEach(async () => {

    [mainAccount, account1, account2, account3] = await ethers.getSigners()

    const AMMMath = await ethers.getContractFactory("AMMMath", mainAccount)
    const library = await AMMMath.deploy()
    await library.deployed()

    // Contract factory for ERC20 tokens
    const ERC20 = await ethers.getContractFactory("Token", mainAccount)
    
    // For each test we create three contracts for different
    // ERC20 tokens: token0, token1, token2
    token0 = await ERC20.deploy("Token0", "TKN0", 1e+9)
    await token0.deployed()
    
    token1 = await ERC20.deploy("Token1", "TKN1", 1e+9)
    await token1.deployed()
    
    token2 = await ERC20.deploy("Token2", "TKN2", 1e+9)
    await token2.deployed()
    
    // Contract factory for token0-token1 pool
    AMMPair = await ethers.getContractFactory("AMMPair", {
      signer: mainAccount,
      libraries: {
        AMMMath: library.address,
      },
    })
    
    // pool deployment
    pool = await AMMPair.deploy(token0.address, token1.address)
    await pool.deployed()

    // approval of token spending (token0, token1, LP tokens)
    await token0.approve(pool.address, 1e+9)
    await token1.approve(pool.address, 1e+9)
    await pool.approve(pool.address, 1e+9)

  })

  describe("constructor", () => {
    it("shouldn't accept in constructor zero addresses", async () => {      
      // one of tokens has zero address
      await expect(
        AMMPair.deploy(ethers.constants.AddressZero, token0.address)
      ).to.be.revertedWith("AMMPair: zero address");
      
      // both of them have zero addresses
      await expect(
        AMMPair.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero)
      ).to.be.revertedWith("AMMPair: zero address");
    })

    it("should set the symbol and the name for LP tokens", async () => {
      expect(await pool.name()).to.equal("LPToken")
      expect(await pool.symbol()).to.equal("LP")
    })

  })


  describe("addLiquidity", () => {
    it("the input amounts should be nonzero integers", async () => {
      await expect(
        pool.addLiquidity(0, 13333333, mainAccount.address)
      ).to.be.revertedWith("AMMPair: invalid amount");
      
      await expect(
        pool.addLiquidity(0, 0, mainAccount.address)
      ).to.be.revertedWith("AMMPair: invalid amount");
    })

    describe("adding liquidity to empty pool", () => {
      it("should allow to set initial pool ratio", async () => {
        const tx = await pool.addLiquidity(101, 400623, mainAccount.address)
        
        expect(
          parseInt(await provider.getStorageAt(pool.address, 5))
        ).to.equal(101)
        
        expect(
          parseInt(await provider.getStorageAt(pool.address, 6))
        ).to.equal(400623)
        
        await expect(() => tx).to.changeTokenBalances(token0, [mainAccount, pool], [-101, 101])
        await expect(() => tx).to.changeTokenBalances(token1, [mainAccount, pool], [-400623, 400623])
        await expect(() => tx).to.changeTokenBalance(pool, mainAccount, 6361)
      })
    })

    describe("adding liquidity to nonempty pool", () => {
      it("proportional amounts", async () => {
        await pool.addLiquidity(200000, 300000, mainAccount.address)
  
        await token0.transfer(account1.address, 1e+6)
        await token1.transfer(account1.address, 1e+6)
        await token0.connect(account1).approve(pool.address, 1e+6)
        await token1.connect(account1).approve(pool.address, 1e+6)
  
        const tx = await pool.addLiquidity(600, 900, await account1.getAddress())
        await tx.wait()
  
        expect(
          parseInt(await provider.getStorageAt(pool.address, 5))
        ).to.equal(200600)
        
        expect(
          parseInt(await provider.getStorageAt(pool.address, 6))
        ).to.equal(300900)
        
        await expect(() => tx).to.changeTokenBalances(token0, [mainAccount, account1, pool], [0, -600, 600])
        await expect(() => tx).to.changeTokenBalances(token1, [mainAccount, account1, pool], [0, -900, 900])
        await expect(() => tx).to.changeTokenBalances(pool, [mainAccount, account1], [0, 734])
      })

      it("disproportionate amounts", async () => {
        await pool.addLiquidity(100, 993700, mainAccount.address)
  
        await token0.transfer(account2.address, 100000)
        await token1.transfer(account2.address, 100000)
        await token0.connect(account2).approve(pool.address, 100000)
        await token1.connect(account2).approve(pool.address, 100000)
  
        let tx = await pool.connect(account2).addLiquidity(100000, 9937, await account2.getAddress())
        await tx.wait()
        
        // check token0
        expect(
          parseInt(await provider.getStorageAt(pool.address, 5))
        ).to.equal(100100)
        
        // check token1
        expect(
          parseInt(await provider.getStorageAt(pool.address, 6))
        ).to.equal(1003637)
        
        await expect(() => tx).to.changeTokenBalances(token0, [account2, pool], [-100000, 100000])
        await expect(() => tx).to.changeTokenBalances(token1, [account2, pool], [-9937, 9937])
        
        // Because user added liquidity in unproportional ratio,
        // a punishment will be applied: less LP tokens minted
        await expect(() => tx).to.changeTokenBalance(pool, account2, 99) // 99 LP
        
        // The actual ratio is influenced by the previous liquidity provider.
        // The provided liquidity is too small, thus the provider is penalized
        // by receiving 0 LP tokens and loosing liquidity
        tx = await pool.addLiquidity(10, 20, mainAccount.address)
        await tx.wait()
  
        expect(
          parseInt(await provider.getStorageAt(pool.address, 5))
        ).to.equal(100110)
        
        expect(
          parseInt(await provider.getStorageAt(pool.address, 6))
        ).to.equal(1003657)
        
        await expect(() => tx).to.changeTokenBalances(token0, [mainAccount, account2, pool], [-10, 0, 10])
        await expect(() => tx).to.changeTokenBalances(token1, [mainAccount, account2, pool], [-20, 0, 20])
        await expect(() => tx).to.changeTokenBalances(pool, [mainAccount,  account2], [0, 0])
      })

    })

  })
  
  describe("removeLiquidity", () => {
    it("the amount of liquidity to burn must be a positive integer", async () => {
      await expect(pool.removeLiquidity(0, mainAccount.address))
        .to.be.revertedWith("AMMPair: invalid amount");
    })
    
    it("shouldn't remove more than actual LP token balanace of account", async () => {
      await pool.addLiquidity(100, 100, mainAccount.address) // 100 LP
      await expect(pool.removeLiquidity(101, mainAccount.address))
        .to.be.revertedWith("AMMPair: insuffcient amount of LP tokens")
    })

    describe("liquidity removal", () => {
      describe("removal by first liquidity provider", () => {
        it("removal by first liquidity provider", async () => {
          await pool.addLiquidity(1000, 4000, mainAccount.address) // 2000 LP
          
          let tx = await pool.removeLiquidity(1010, mainAccount.address)
          await tx.wait()
    
          await expect(() => tx).to.changeTokenBalances(token0, [mainAccount, pool], [505, -505])
          await expect(() => tx).to.changeTokenBalances(token1, [mainAccount, pool], [2020, -2020])
          await expect(() => tx).to.changeTokenBalance(pool, mainAccount, -1010)
        })
      })

      describe("removal by random provider", () => {
        const initSetup = async (
          account,
          amount0MainAccount, 
          amount1MainAccount, 
          amount0Account, 
          amount1Account
        ) => {
          // initial liquidity
          // LPinit = sqrt(amount0 * amount1)
          await pool.addLiquidity(amount0MainAccount, amount1MainAccount, mainAccount.address)

          // token approval for pool address (transfer on account2's behalf)
          await token0.connect(account).approve(pool.address, 1e+9)
          await token1.connect(account).approve(pool.address, 1e+9)

          // transfer tokens to account2
          await token0.transfer(account.address, 100000)
          await token1.transfer(account.address, 100000)

          // liquidity provided by another account (according to initial ratio)
          await pool.addLiquidity(amount0Account, amount1Account, await account.getAddress())
        }

        it("proportional case", async () => {
          await initSetup(account2, 200, 80000, 10, 4000)
          //mainAccount - 4000 LP, account2 - 200 LP
          
          // liquidity removal by first provider
          let tx = await pool.removeLiquidity(2000, mainAccount.address)
          await tx.wait()

          // balance of main account changes accordingly
          // balance of account2 remains unchanged
          await expect(() => tx).to.changeTokenBalances(token0, [mainAccount, account2, pool], [100, 0, -100])
          await expect(() => tx).to.changeTokenBalances(token1, [mainAccount, account2, pool], [40000, 0, -40000])
          await expect(() => tx).to.changeTokenBalances(pool, [mainAccount, account2], [-2000, 0])

          // liquidity removal by second provider (account2)
          tx = await pool.removeLiquidity(200, await account2.getAddress())
          await tx.wait()

          // balance of account2 changes accordingly
          // balance of main account remains unchanged
          await expect(() => tx).to.changeTokenBalances(token0, [mainAccount, account2, pool], [0, 10, -10])
          await expect(() => tx).to.changeTokenBalances(token1, [mainAccount, account2, pool], [0, 4000, -4000])
          await expect(() => tx).to.changeTokenBalances(pool, [mainAccount, account2], [0, -200])
        })

        it("dispropotionate case", async () => {
          await initSetup(account1, 2000, 320, 3000, 27000)
          // mainAccount - 800 LP, account2 - 1200 LP

          // liquidity removal by second provider (account1)
          let tx = await pool.removeLiquidity(1200, await account1.getAddress()) // all account1's LP tokens burned
          await tx.wait()

          // For adding liquidity in wrong ratio, account1 is punnished
          // by receiving back less liquidity (token0: 3000, token1: 16392 (not 27000))
          await expect(() => tx).to.changeTokenBalances(token0, [mainAccount, account1, pool], [0, 3000, -3000])
          await expect(() => tx).to.changeTokenBalances(token1, [mainAccount, account1, pool], [0, 16392, -16392])
          await expect(() => tx).to.changeTokenBalances(pool, [mainAccount, account1], [0, -1200])
        })
      })

    })
    
  })
  
  describe("getPrice", () => {
    it("should revert if token isn't in pool", async () => {
      await expect(pool.getPrice(token2.address))
        .to.be.revertedWith("AMMPair: token inexistent in pair")
    })

    it("should get the correct token price", async () => {
      await pool.addLiquidity(5000, 9999, mainAccount.address)
      expect((await pool.getPrice(token0.address)).toNumber() / 1e+9).to.equal(1.9998)
      expect((await pool.getPrice(token1.address)).toNumber() / 1e+9).to.equal(0.500050005)
      
      await pool.addLiquidity(5000, 1, mainAccount.address)
      expect((await pool.getPrice(token0.address)).toNumber() / 1e+9).to.equal(1)
      expect((await pool.getPrice(token1.address)).toNumber() / 1e+9).to.equal(1)

      await pool.addLiquidity(343434, 10, mainAccount.address)
      expect((await pool.getPrice(token0.address)).toNumber() / 1e+9).to.equal(0.028322119)
      expect((await pool.getPrice(token1.address)).toNumber() / 1e+9).to.equal(35.308091908)
    })
  })


  describe("swap", () => {
    beforeEach(async () => {
      await pool.addLiquidity(10000, 30000, mainAccount.address)
      
      // token approval for pool address (transfer on account1's behalf)
      await token0.connect(account3).approve(pool.address, 1e+9)
      await token1.connect(account3).approve(pool.address, 1e+9)
      
      // transfer tokens to account3
      await token0.transfer(account3.address, 1e+6)
      await token1.transfer(account3.address, 1e+6)
    })

    it("shouldn't allow foreign tokens", async () => {
      await expect(pool.swap(token2.address, 123, token0.address, mainAccount.address))
        .to.be.revertedWith("AMMPair: token inexistent in pair")
    })

    it("the asset chosen for fee retaining must be in pool", async () => {
      await expect(pool.swap(token1.address, 123, token2.address, mainAccount.address))
        .to.be.revertedWith("AMMPair: token inexistent in pair")
    })

    it("the amount of tokens to swap must be a nonzero value", async () => {
      await expect(pool.swap(token1.address, 0, token0.address, mainAccount.address))
        .to.be.revertedWith("AMMPair: invalid amount")
    })

    it("should revert if output amount is insufficient", async () => {
      await expect(pool.swap(token0.address, 1, token0.address, account3.address))
      .to.be.revertedWith("AMMPair: insufficient output amount")
    })

    describe("choiseAssetFee is _tokenIn", () => {
      it("should give out the correct amount of token1 given token0 (direct swap) ", async () => {
        const tx = await pool.swap(token0.address, 333, token0.address, account3.address)
        await tx.wait()

        // check balanceToken0
        expect(
          parseInt(await provider.getStorageAt(pool.address, 5))
        ).to.equal(10333)
        
        // check balanceToken1
        expect(
          parseInt(await provider.getStorageAt(pool.address, 6))
        ).to.equal(29037)

        await expect(() => tx).to.changeTokenBalances(token0, [account3, pool], [-333, 333])
        await expect(() => tx).to.changeTokenBalances(token1, [account3, pool], [963, -963])
      })

      it("should give out the correct amount of token0 given token1 (swap reversed) ", async () => {
        const tx = await pool.connect(account3).swap(token1.address, 200, token1.address, account3.address)
        await tx.wait()

        // check balanceToken0
        expect(
          parseInt(await provider.getStorageAt(pool.address, 5))
        ).to.equal(9935)
        
        // check balanceToken1
        expect(
          parseInt(await provider.getStorageAt(pool.address, 6))
        ).to.equal(30200)

        await expect(() => tx).to.changeTokenBalances(token0, [account3, pool], [65, -65])
        await expect(() => tx).to.changeTokenBalances(token1, [account3, pool], [-200, 200])
      })
    })

    describe("choiseAssetFee is _tokenOut", () => {
      it("should give out the correct amount of token1 given token0 (direct swap) ", async () => {
        const tx = await pool.connect(account3).swap(token0.address, 444, token1.address, account3.address)
        await tx.wait()

        // check balanceToken0
        expect(
          parseInt(await provider.getStorageAt(pool.address, 5))
        ).to.equal(10444)
        
        // check balanceToken1
        expect(
          parseInt(await provider.getStorageAt(pool.address, 6))
        ).to.equal(28729)

        await expect(() => tx).to.changeTokenBalances(token0, [account3, pool], [-444, 444])
        await expect(() => tx).to.changeTokenBalances(token1, [account3, pool], [1271, -1271])
      })

      it("should give out the correct amount of token0 given token1 (swap reversed) ", async () => {
        const tx = await pool.connect(account3).swap(token1.address, 300, token0.address, account3.address)
        await tx.wait()

        // check balanceToken0
        expect(
          parseInt(await provider.getStorageAt(pool.address, 5))
        ).to.equal(9902)
        
        // check balanceToken1
        expect(
          parseInt(await provider.getStorageAt(pool.address, 6))
        ).to.equal(30300)

        await expect(() => tx).to.changeTokenBalances(token0, [account3, pool], [98, -98])
        await expect(() => tx).to.changeTokenBalances(token1, [account3, pool], [-300, 300])
      })
    })
  })

  describe("sendLiquidity", () => {
    it("shouldn't allow to send zero amount of tokens", async () => {
      await expect(pool.sendLiquidity(0, mainAccount.address, account1.address))
        .to.be.revertedWith("AMMPair: zero amount")
    })

    it("shouldn't allow to transfer to zero address", async () => {
      await expect(pool.sendLiquidity(10, mainAccount.address, ethers.constants.AddressZero))
        .to.be.revertedWith("AMMPair: transfer to zero address")
    })

    it("shouldn't allow transfer from zero address", async () => {
      await expect(pool.sendLiquidity(10, ethers.constants.AddressZero, mainAccount.address))
        .to.be.revertedWith("AMMPair: transfer from zero address")
    })

    it("should send liquidity to provided address", async () => {
      await pool.addLiquidity(100, 400, mainAccount.address) // 200 LP
      
      const tx = await pool.sendLiquidity(100, mainAccount.address, account1.address)
      await tx.wait()

      await expect(() => tx).to.changeTokenBalances(pool, [mainAccount, account1], [-100, 100])

    })
  })

})

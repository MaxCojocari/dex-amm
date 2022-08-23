const { expect } = require("chai");
const { ethers } = require("hardhat");
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

describe("AMMStaking", () => {
    let owner
    let account
    let extraAccount
    let token
    let stakingManager

    beforeEach(async () => {
        [owner, account, extraAccount] = await ethers.getSigners()

        const AMMStaking = await ethers.getContractFactory("AMMStaking", owner)
        stakingManager = await AMMStaking.deploy(10)
        await stakingManager.deployed()

        const Token = await ethers.getContractFactory("Token", owner)
        token = await Token.deploy("TestToken", "TKN", 1e+9)
        await token.deployed()

        await token.approve(stakingManager.address, 1e+9)
        await token.transfer(account.address, 1e+5)
        await token.transfer(extraAccount.address, 1e+5)
        await token.connect(account).approve(stakingManager.address, 1e+5)
        await token.connect(extraAccount).approve(stakingManager.address, 1e+5)
    })

    describe("constructor", () => {
        it("should set the name and the symbol of reward token", async () => {
            expect(await stakingManager.name()).to.equal("TitaniumSweet")
            expect(await stakingManager.symbol()).to.equal("TSW")
            expect(await stakingManager.totalSupply()).to.equal(0)
        })

        it("should set the owner and nr of reward tokens per block", async () => {
            expect(await stakingManager.owner()).to.equal(owner.address)
            expect(
                parseInt(
                    await ethers.provider.getStorageAt(stakingManager.address, 6)
                )
            ).to.equal(10)
        })
    })

    // for(let i = 0; i < 100; ++i) {
    //     console.log(
    //         await ethers.provider.getStorageAt(stakingManager.address, i)
    //     )
    // }

    describe("createPool", () => {
        it("should accept as creator only contract owner", async () => {
            await expect(stakingManager.connect(account).createPool(token.address))
                .to.be.revertedWith("AMMStaking: not an owner")
        })
        
        it("should create a new pool", async () => {
            await stakingManager.createPool(token.address)

            const output = await stakingManager.callStatic.getPool(0)
            
            expect(output.tokenAddress).to.equal(token.address)
            expect(output.tokensStaked).to.equal(0)
            expect(output.stakers).to.eql([])
        })

        it("should emit an event", async () => {
            await expect(stakingManager.createPool(token.address))
                .to.emit(stakingManager, "PoolCreated")
                .withArgs(0)
        })
    })

    describe("deposit", () => {
        beforeEach(async () => {
            await stakingManager.createPool(token.address)
        })

        it("should revert if deposited amount is zero", async () => {
            await expect(stakingManager.deposit(0, 0))
                .to.be.revertedWith("AMMStaking: invalid amount")         
        })

        it("should add a new staker in the pool", async () => {
            // we ensure that staker entered his position for the first time
            let output = await stakingManager.callStatic.getStaker(0)
            expect(output.exists).to.be.false
            
            const tx = await stakingManager.deposit(0, 100)
            await tx.wait()

            output = await stakingManager.callStatic.getStaker(0)
            expect(output.amountDeposited).to.equal(100)
            expect(output.exists).to.be.true

            output = await stakingManager.callStatic.getPool(0)
            expect(output.tokensStaked).to.equal(100)
            expect(output.stakers[0]).to.equal(owner.address)
        })

        it("should deposit funds for new staker", async () => {
            await stakingManager.createPool(token.address)
            
            const tx = await stakingManager.connect(account).deposit(1, 222)
            await tx.wait()

            await expect(() => tx)
                .to.changeTokenBalances(token, [stakingManager, account], [222, -222])
            
            let output = await (stakingManager.connect(account)).callStatic.getStaker(1)
            expect(output.amountDeposited).to.equal(222)

            output = await stakingManager.callStatic.getPool(1)
            expect(output.stakers[0]).to.equal(account.address)
            expect(output.tokensStaked).to.equal(222)

        })

        it("should deposit funds for an existent staker in pool", async () => {
            await stakingManager.deposit(0, 100)

            // somebody else also deposited some tokens 
            await stakingManager.connect(account).deposit(0, 100)

            // previous staker again deposited some funds
            const tx = await stakingManager.deposit(0, 300)
            await tx.wait()

            await expect(() => tx)
                .to.changeTokenBalances(token, [stakingManager, owner], [300, -300])

            let output = await stakingManager.callStatic.getStaker(0)
            expect(output.amountDeposited).to.equal(400)

            output = await stakingManager.callStatic.getPool(0)
            expect(output.tokensStaked).to.equal(500)
        })

        it("should emit an event", async () => {
            await expect(stakingManager.deposit(0, 123))
                .to.emit(stakingManager, "Deposit")
                .withArgs(owner.address, 0, 123)
        })
    })

    describe("harvestRewards", () => {
        beforeEach(async () => {
            await stakingManager.createPool(token.address)

            await stakingManager.deposit(0, 1000)
            await stakingManager.connect(account).deposit(0, 600)
            await stakingManager.connect(extraAccount).deposit(0, 700)
        })

        it("should revert if nr stakers is < 3", async () => {
            await stakingManager.createPool(token.address)

            await stakingManager.deposit(1, 10)
            await expect(stakingManager.withdraw(1))
                .to.be.revertedWith("AMMStaking: nr stakers < 3")

        })

        it("should return the correct accumulated reward", async () => {
            let beforeBlocksMined = (await ethers.provider.getBlock("latest")).number
            
            // wait until extra 200 blocks are mined
            await mine(200)

            // contract owner withdraws all funds
            const tx1 = await stakingManager.withdraw(0)
            await tx1.wait()
            
            let afterBlocksMined = (await ethers.provider.getBlock("latest")).number
            
            // get the info amount staker after withdrawing funds
            let output = await stakingManager.callStatic.getStaker(0)
            
            // the number of mined blocks is bigger with 2, 
            // because in beforeEach statement, account and extraAccount deposited also
            let blocksSinceLastReward = afterBlocksMined - beforeBlocksMined + 2;
            
            // computing expected rewards
            let expectedOutput = parseInt((1000 * blocksSinceLastReward * 10) / (1000 + 600 + 700))

            expect(output.rewards).to.equal(expectedOutput) 

            // ensure that amount of minted tokens is transfered as well
            await expect(() => tx1)
                .to.changeTokenBalance(stakingManager, owner, expectedOutput)           
            
            
            
            // testing for account (simmilar approach)
            await stakingManager.connect(account).deposit(0, 500)            
            
            await mine(1000)
            
            const tx2 = await stakingManager.connect(account).withdraw(0)
            await tx2.wait()
            
            afterBlocksMined = (await ethers.provider.getBlock("latest")).number
            
            output = await (stakingManager.connect(account)).callStatic.getStaker(0)
            
            blocksSinceLastReward = afterBlocksMined - beforeBlocksMined + 1;

            expectedOutput = parseInt(((600 + 500) * blocksSinceLastReward * 10) / (600 + 700 + 500))
            
            expect(output.rewards).to.equal(expectedOutput)

            await expect(() => tx2)
                .to.changeTokenBalance(stakingManager, account, expectedOutput)
        })

        it("should emit an event", async () => {
            await expect(stakingManager.withdraw(0))
                .to.emit(stakingManager, "HarvestRewards")
                .withArgs(owner.address, 0, 13)
        })
    })

    describe("withdraw", () => {
        beforeEach(async () => {
            await stakingManager.createPool(token.address)

            await stakingManager.deposit(0, 1000)
            await stakingManager.connect(account).deposit(0, 600)
            await stakingManager.connect(extraAccount).deposit(0, 700)
        })

        it("should set the deposited amount to 0", async () => {
            await stakingManager.connect(extraAccount).withdraw(0)

            const output = await (stakingManager.connect(extraAccount)).callStatic.getStaker(0)
            expect(output.amountDeposited).to.equal(0)
        })

        it("should decrease the amount of deposited tokens in pool", async () => {
            await stakingManager.connect(account).withdraw(0)

            const output = await stakingManager.callStatic.getPool(0)
            expect(output.tokensStaked).to.equal(1700)
        })

        it("should emit an event", async () => {
            await expect(stakingManager.withdraw(0))
                .to.emit(stakingManager, "Withdraw")
                .withArgs(owner.address, 0, 1000)
        })

        it("should tranfer back the lacked tokens", async () => {
            const tx = await stakingManager.withdraw(0)
            await tx.wait()

            await expect(() => tx)
                .to.changeTokenBalances(token, [owner, stakingManager], [1000, -1000])
        })
    })

})
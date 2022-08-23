const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AMMFactoryETH", () => {
    let signer
    let token
    let factory

    beforeEach(async () => {
        [signer] = await ethers.getSigners()

        const AMMMath = await ethers.getContractFactory("AMMMath", signer)
        const library = await AMMMath.deploy()
        await library.deployed()

        const AMMFactoryETH = await ethers.getContractFactory("AMMFactoryETH", {
            signer: signer,
            libraries: {
                AMMMath: library.address,
            },
        })

        factory = await AMMFactoryETH.deploy()
        await factory.deployed()

        const ERC20 = await ethers.getContractFactory("Token", signer)
        token = await ERC20.deploy("TestToken", "TKN", 100)
        await token.deployed()
    })

    describe("addPair", () => {
        it("shouldn't accept zero address", async () => {
            await expect(factory.addPair(ethers.constants.AddressZero))
                .to.be.revertedWith("AMMFactoryETH: zero address")
        })

        it("should add only inexistent pairs", async () => {
            await factory.addPair(token.address)

            await expect(factory.addPair(token.address))
                .to.be.revertedWith("AMMFactoryETH: pair already exists")
        })

        it("should add properly a new address", async () => {
            const output = await factory.callStatic.addPair(token.address)

            await factory.addPair(token.address)

            expect(
                await factory.getAddressPair(token.address)
            ).to.equal(output)
        })

        it("should emit an event", async () => {
            await expect(factory.addPair(token.address))
                .to.emit(factory, 'AddPair')
                .withArgs(
                    token.address,
                    await factory.callStatic.getAddressPair(token.address)
                )
        })
    })

    describe("getPairToken", () => {
        it("should get the correct pool address", async () => {
            const output = await factory.callStatic.addPair(token.address)

            await factory.addPair(token.address)

            expect(
                await factory.getAddressPair(token.address)
            ).to.equal(output)
        })

        it("should return zero address if pool doesn't exist", async () => {
            expect(
                await factory.getAddressPair(token.address)
            ).to.equal(ethers.constants.AddressZero)
        })
    })
})
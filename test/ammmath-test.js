const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AMMMath", () => {
  let signer
  let library

  beforeEach(async () => {
    [signer] = await ethers.getSigners()

    const AMMMath = await ethers.getContractFactory("AMMMath", signer)
    library = await AMMMath.deploy()
    await library.deployed()
  })

  describe("sqrt", () => {
    it("should return the correct floored value", async () => {
      const values = [
        (await library.sqrt(0)).toNumber(),
        (await library.sqrt(2)).toNumber(),
        (await library.sqrt(4)).toNumber(),
        (await library.sqrt(100)).toNumber(),
        (await library.sqrt(10000)).toNumber(),
        (await library.sqrt(46175872)).toNumber()
      ]
      expect(values).to.eql([0, 1, 2, 10, 100, 6795])
    })
  })

  describe("min", () => {
    it("should return the correct min value", async () => {
      const minValues = [
        (await library.min(1, 1)).toNumber(),
        (await library.min(1872348, 0)).toNumber(),
        (await library.min(12121, 12122)).toNumber()
      ]
      expect(minValues).to.eql([1, 0, 12121])
    })
  })
})
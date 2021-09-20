const {ethers} = require("ethers");
const BN = require('bn.js');

const VanityNamePrices = artifacts.require('VanityNamePrices');

contract('VanityNamePrices Test', function () {
    let vnPricesInstance;

    before(async () => {
        vnPricesInstance = await VanityNamePrices.deployed();

        await vnPricesInstance.setPrices([
            0, 
            0, 
            ethers.utils.parseEther("1"), 
            ethers.utils.parseEther("1.5"), 
            ethers.utils.parseEther("2"), 
            ethers.utils.parseEther("2.25"),
            ethers.utils.parseEther("3")
        ]);
    });

    it('should return correct prices', async () => {
        assert.equal((await vnPricesInstance.price("foo")).toString(), new BN(ethers.utils.parseEther("1").toString()).toString());
        assert.equal((await vnPricesInstance.price("quux")).toString(), new BN(ethers.utils.parseEther("1.5").toString()).toString());
        assert.equal((await vnPricesInstance.price("fubar")).toString(), new BN(ethers.utils.parseEther("2").toString()).toString());
        assert.equal((await vnPricesInstance.price("foobie")).toString(), new BN(ethers.utils.parseEther("2.25").toString()).toString());
    });
});
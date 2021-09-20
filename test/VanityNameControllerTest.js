const {ethers} = require("ethers");
const { evm, exceptions } = require("./test-utils");
const sha3 = require('web3-utils').sha3;
const BN = require('bn.js');

const VanityNameRegistrar = artifacts.require('VanityNameRegistrar');
const VanityNamePrices = artifacts.require('VanityNamePrices');
const VanityNameController = artifacts.require('VanityNameController');

contract('VanityNameController Test', function (accounts) {
    let vnRegistrarInstance;
    let vnPricesInstance;
    let vnControllerInstance;

    const lockingAmount = ethers.utils.parseEther("0.5");
    const gracePeriod = 60 * 5; // 5 minutes
    const registrerPeriod = 60 * 60; // 60 minutes
    const minCommitmentAge = 60; // 60 seconds
    const maxCommitmentAge = 60 * 2; // 2 minutes
    const secret = "0xebf2c9407ef0e8f63f126b5f9b773bcd0ba8e94f77febccf0f3015a9371825c5";
    const ownerAccount = accounts[0]; // Account that owns the registrar
    const registrantAccount = accounts[1]; // Account that owns test names
    const registrantAccountOther = accounts[2]; // Account that owns test names

    const checkLabels = {
        "testing": true,
        "longname12345678": true,
        "sixsix": true,
        "five5": true,
        "four": true,
        "iii": true,
        "ii": false,
        "i": false,
        "": false,

        // { ni } { hao } { ma } (chinese; simplified)
        "\u4f60\u597d\u5417": true,

        // { ta } { ko } (japanese; hiragana)
        "\u305f\u3053": false,

        // { poop } { poop } { poop } (emoji)
        "\ud83d\udca9\ud83d\udca9\ud83d\udca9": true,

        // { poop } { poop } (emoji)
        "\ud83d\udca9\ud83d\udca9": false
    };

    before(async () => {
        vnRegistrarInstance = await VanityNameRegistrar.deployed();

        vnPricesInstance = await VanityNamePrices.deployed();

        vnControllerInstance = await VanityNameController.deployed();

        await vnRegistrarInstance.setGracePeriod(gracePeriod);

        await vnPricesInstance.setPrices([
            0, 
            0, 
            ethers.utils.parseEther("1"), 
            ethers.utils.parseEther("1.5"), 
            ethers.utils.parseEther("2"), 
            ethers.utils.parseEther("2.25"),
            ethers.utils.parseEther("3")
        ]);

        await vnControllerInstance.setLockingParameters(
            lockingAmount,
            registrerPeriod
        );

        await vnControllerInstance.setCommitmentAges(
            minCommitmentAge,
            maxCommitmentAge
        );

        await vnRegistrarInstance.setController(
            vnControllerInstance.address
        );
    });

    it('should report label validity', async () => {
        for (const label in checkLabels) {
            assert.equal(await vnControllerInstance.valid(label), checkLabels[label], label);
        }
    });

    it('should report unused names as available', async () => {
        assert.equal(await vnControllerInstance.available(sha3('available')), true);
    });

    it('should permit new registrations', async () => {
        var priceForLabel = new BN((await vnPricesInstance.price("newname")).toString());
        var valueForSend = priceForLabel.add(new BN(lockingAmount.toString()));
        var commitment = await vnControllerInstance.makeCommitment("newname", registrantAccount, secret);
        var tx = await vnControllerInstance.commit(commitment);
        assert.equal(await vnControllerInstance.commitments(commitment), (await web3.eth.getBlock(tx.receipt.blockNumber)).timestamp);

        await evm.advanceTime((await vnControllerInstance.minCommitmentAge()).toNumber());
        var balanceBefore = await web3.eth.getBalance(vnControllerInstance.address);
        var tx = await vnControllerInstance.register("newname", registrantAccount, secret, {value: valueForSend.toString(), gasPrice: 0});
        assert.equal(tx.logs.length, 1);
        assert.equal(tx.logs[0].event, "NameRegistered");
        assert.equal(tx.logs[0].args.name, "newname");
        assert.equal(tx.logs[0].args.owner, registrantAccount);
        assert.equal((await web3.eth.getBalance(vnControllerInstance.address)) - balanceBefore, valueForSend);
    });

    it('should report registered names as unavailable', async () => {
        assert.equal(await vnControllerInstance.available('newname'), false);
    });

    it('should reject duplicate registrations', async () => {
        var priceForLabel = new BN((await vnPricesInstance.price("newname")).toString());
        var valueForSend = priceForLabel.add(new BN(lockingAmount.toString()));
        await vnControllerInstance.commit(await vnControllerInstance.makeCommitment("newname", registrantAccount, secret));

        await evm.advanceTime((await vnControllerInstance.minCommitmentAge()).toNumber());
        await exceptions.expectFailure(vnControllerInstance.register("newname", registrantAccount, secret, {value: valueForSend.toString(), gasPrice: 0}));
    });

    it('should reject for expired commitments', async () => {
        var priceForLabel = new BN((await vnPricesInstance.price("newname1")).toString());
        var valueForSend = priceForLabel.add(new BN(lockingAmount.toString()));
        await vnControllerInstance.commit(await vnControllerInstance.makeCommitment("newname1", registrantAccount, secret));

        await evm.advanceTime((await vnControllerInstance.maxCommitmentAge()).toNumber() + 1);
        await exceptions.expectFailure(vnControllerInstance.register("newname1", registrantAccount, secret, {value: valueForSend.toString(), gasPrice: 0}));
    });

    it('should allow anyone to renew a name', async () => {
        var priceForLabel = new BN((await vnPricesInstance.price("newname")).toString());
        var expires = await vnRegistrarInstance.nameExpires(sha3("newname"));
        var balanceBefore = await web3.eth.getBalance(vnControllerInstance.address);
        await vnControllerInstance.renew("newname", {value: priceForLabel.toString()});
        var newExpires = await vnRegistrarInstance.nameExpires(sha3("newname"));
        assert.equal(newExpires.toNumber() - expires.toNumber(), registrerPeriod);
        assert.equal((await web3.eth.getBalance(vnControllerInstance.address)) - balanceBefore, priceForLabel);
    });

    it('should require sufficient value for a renewal', async () => {
        await exceptions.expectFailure(vnControllerInstance.renew("newname"));
    });

    it('should allow the registrar owner to withdraw funds', async () => {
        var lockedAmountSum = await vnControllerInstance.lockedAmountSum();
        await vnControllerInstance.withdraw({gasPrice: 0, from: ownerAccount});
        assert.equal(await web3.eth.getBalance(vnControllerInstance.address), new BN(lockedAmountSum.toString()));
    });

    it('should withdraw locked amount', async () => {
        var priceForLabel = new BN((await vnPricesInstance.price("newname2")).toString());
        var valueForSend = priceForLabel.add(new BN(lockingAmount.toString()));
        var commitment = await vnControllerInstance.makeCommitment("newname2", registrantAccount, secret);
        var tx = await vnControllerInstance.commit(commitment);
        assert.equal(await vnControllerInstance.commitments(commitment), (await web3.eth.getBlock(tx.receipt.blockNumber)).timestamp);

        await evm.advanceTime((await vnControllerInstance.minCommitmentAge()).toNumber());
        var balanceBefore = await web3.eth.getBalance(vnControllerInstance.address);
        var tx = await vnControllerInstance.register("newname2", registrantAccount, secret, {value: valueForSend.toString(), gasPrice: 0});
        assert.equal((await web3.eth.getBalance(vnControllerInstance.address)) - balanceBefore, valueForSend);

        var balanceBeforeAccountMain = await web3.eth.getBalance(registrantAccount);
        await evm.advanceTime(registrerPeriod + gracePeriod + 1);
        await vnControllerInstance.unlockAndWithdrawAmount("newname2", {gasPrice: 0, from:registrantAccount});
        var balanceAfterAccountMain = await web3.eth.getBalance(registrantAccount);
        assert.equal(new BN(balanceBeforeAccountMain).add(new BN(lockingAmount.toString())), balanceAfterAccountMain);
    });

    it('should register name that was already registered', async () => {
        var priceForLabel = new BN((await vnPricesInstance.price("newname2")).toString());
        var valueForSend = priceForLabel.add(new BN(lockingAmount.toString()));
        var commitment = await vnControllerInstance.makeCommitment("newname2", registrantAccountOther, secret);
        var tx = await vnControllerInstance.commit(commitment);
        assert.equal(await vnControllerInstance.commitments(commitment), (await web3.eth.getBlock(tx.receipt.blockNumber)).timestamp);

        await evm.advanceTime((await vnControllerInstance.minCommitmentAge()).toNumber());
        var balanceBefore = await web3.eth.getBalance(vnControllerInstance.address);
        var tx = await vnControllerInstance.register("newname2", registrantAccountOther, secret, {value: valueForSend.toString(), gasPrice: 0});
        assert.equal((await web3.eth.getBalance(vnControllerInstance.address)) - balanceBefore, valueForSend);
    });

    it('should withdraw locked amount that is unlocked from other user', async () => {
        await evm.advanceTime(registrerPeriod + gracePeriod + 1);

        var priceForLabel = new BN((await vnPricesInstance.price("newname2")).toString());
        var valueForSend = priceForLabel.add(new BN(lockingAmount.toString()));
        var commitment = await vnControllerInstance.makeCommitment("newname2", registrantAccount, secret);
        var tx = await vnControllerInstance.commit(commitment);
        assert.equal(await vnControllerInstance.commitments(commitment), (await web3.eth.getBlock(tx.receipt.blockNumber)).timestamp);

        await evm.advanceTime((await vnControllerInstance.minCommitmentAge()).toNumber());
        var balanceBefore = await web3.eth.getBalance(vnControllerInstance.address);
        var tx = await vnControllerInstance.register("newname2", registrantAccount, secret, {value: valueForSend.toString(), gasPrice: 0});
        assert.equal((await web3.eth.getBalance(vnControllerInstance.address)) - balanceBefore, valueForSend);

        var balanceBeforeAccountMain = await web3.eth.getBalance(registrantAccountOther);
        await vnControllerInstance.withdrawUnlockedAmount({gasPrice: 0, from:registrantAccountOther});
        var balanceAfterAccountMain = await web3.eth.getBalance(registrantAccountOther);
        assert.equal(new BN(balanceBeforeAccountMain).add(new BN(lockingAmount.toString())), balanceAfterAccountMain);
    });
});
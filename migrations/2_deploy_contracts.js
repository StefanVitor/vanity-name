const {ethers} = require("ethers");

const VanityNameRegistrar = artifacts.require("VanityNameRegistrar");
const gracePeriod = 60 * 60 * 24 * 7; // 7 days

const VanityNamePrices = artifacts.require("VanityNamePrices");
const VanityNameController = artifacts.require("VanityNameController");
const lockingAmount = ethers.utils.parseEther("0.01");
const registerPeriod = 60 * 60 * 24 * 182; // 6 months
const minCommitmentAge = 60; // 1 minute
const maxCommitmentAge = 60 * 60 * 24; //1 day

module.exports = async function (deployer) {
  // deploy VarityNameRegistrar
  await deployer.deploy(VanityNameRegistrar, gracePeriod);
  const VanityNameRegistrarInstance = await VanityNameRegistrar.deployed();
  const VarntyNameRegistrarAddress = VanityNameRegistrarInstance.address;
  
  // deploy BaseRegistrarImplementation
  await deployer.deploy(VanityNamePrices, [0]);
  const VanityNamePricesIntance = await VanityNamePrices.deployed();
  const VanityNamePricesAddress = VanityNamePricesIntance.address;

  await deployer.deploy(VanityNameController, VanityNamePricesAddress, VarntyNameRegistrarAddress, 
    lockingAmount, registerPeriod,
    minCommitmentAge, maxCommitmentAge);
};

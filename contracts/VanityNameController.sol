// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/StringUtils.sol";
import "./VanityNameRegistrar.sol";
import "./VanityNamePrices.sol";

contract VanityNameController is Ownable {
    using StringUtils for *;

    mapping(bytes32=>uint256) public commitments;

    VanityNamePrices prices;
    VanityNameRegistrar registrar;

    // Amount that should be locked for every registration
    uint256 private lockingAmount;
    // Registration period
    uint256 private registerPeriod;
    // Sum of locked amount
    uint256 public lockedAmountSum;

    uint256 public minCommitmentAge;
    uint256 public maxCommitmentAge;

    struct LockingRecord {
        uint256 amount;     // How many LP tokens the user has provided.
        address owner;
    }
    // For every tokenId how much amount is locked (if controller has changes about lock amount)
    mapping(uint256=>LockingRecord) public lockingAmounts;
    // Unlocked amounts per address
    mapping(address=>uint256) public unlockedAmounts;

    event NameRegistered(string name, bytes32 indexed label, address indexed owner, uint cost, uint expires);
    event NameRenewed(string name, bytes32 indexed label, uint cost, uint expires);
    event NewPrices(address indexed prices);

    constructor(VanityNamePrices _prices, VanityNameRegistrar _registrar, 
        uint256 _lockingAmount, uint256 _registerPeriod,
        uint256 _minCommitmentAge, uint256 _maxCommitmentAge
    ) {
        prices = _prices;
        registrar = _registrar;

        lockingAmount = _lockingAmount;
        registerPeriod = _registerPeriod;

        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
    }

    /**
     * @dev Setter for locking variables
     * @param _lockingAmount Amount that will be locked after register name 
     * @param _registerPeriod Period for how long will be name register
     */
    function setLockingParameters(uint _lockingAmount, uint _registerPeriod) public onlyOwner {
        lockingAmount = _lockingAmount;
        registerPeriod = _registerPeriod;
    }

    /**
     * @dev Setter for commitment ages
     * @param _minCommitmentAge Min commitment period
     * @param _maxCommitmentAge Max commitment period 
     */
    function setCommitmentAges(uint _minCommitmentAge, uint _maxCommitmentAge) public onlyOwner {
        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
    }

    /**
     * @dev Setter for prices contract
     * @param _prices Prices contract
     */
    function setPrices(VanityNamePrices _prices) public onlyOwner {
        prices = _prices;
        emit NewPrices(address(prices));
    }

    /**
     * @dev Get price for specified name
     * @param name Name for which it should be get price
     */
    function rentPrice(string memory name) view public returns(uint) {
        return prices.price(name);
    }

     /**
     * @dev Get is name valid
     * @param name Name that should be check is valid
     */
    function valid(string memory name) public pure returns(bool) {
        return name.strlen() >= 3;
    }

    /**
     * @dev Check is specified name available
     * @param name Name that should be check is available
     */
    function available(string memory name) public view returns(bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && registrar.available(uint256(label));
    }

    /**
     * @dev Make commitment how to prevent front-run
     * @param name Name that should be check is available
     * @param owner Owner for chosen name
     * @param secret Secret value 
     */
    function makeCommitment(string memory name, address owner, bytes32 secret) pure public returns(bytes32) {
        bytes32 label = keccak256(bytes(name));
        return keccak256(abi.encodePacked(label, owner, secret));
    }

    /**
     * @dev Commit chosen name, how no one could picked in maxCommitmentAge time
     * @param commitment Name that should be check is available
     */
    function commit(bytes32 commitment) public {
        require(commitments[commitment] + maxCommitmentAge < block.timestamp, "VanityNameController: Max commitment age had passed");
        commitments[commitment] = block.timestamp;
    }

    /**
     * @dev Withdraw amounts that are payed for names
     */
    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance - lockedAmountSum);        
    }

    /**
     * @dev Withdraw locked amount from expired name
     * @param name Name for which should be withdraw lockedAmount + unlocked amounts from others tokens which are unlocked
     */
    function withdrawLockedAmount(string memory name) public {
        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);

        // Unlock amount for current tokenId (if it was from msg.sender and currently is available)
        if (lockingAmounts[tokenId].owner == msg.sender && registrar.available(tokenId) == true) {
            _unlockedAmount(tokenId);
        }

        withdrawLockedAmountUnlocked();    
    }

    /**
     * @dev Withdraw locked amount that other users unlocked
     */
    function withdrawLockedAmountUnlocked() public {
        uint256 amountForUnlock = unlockedAmounts[msg.sender];
        unlockedAmounts[msg.sender] = 0;
        payable(msg.sender).transfer(amountForUnlock);      
    }

    /**
     * @dev Register specified name on registerPeriod
     * @param name Name that should be register
     * @param owner Owner that register name
     * @param secret Secret value 
     */
    function register(string memory name, address owner, bytes32 secret) public payable {
        bytes32 commitment = makeCommitment(name, owner, secret);
        uint cost = _consumeCommitment(name, commitment);

        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);

        // Return locking amount if user for this token still hasn't unlock amount
        if (lockingAmounts[tokenId].amount > 0) {
            _unlockedAmount(tokenId);
        }

        uint expires = registrar.register(tokenId, owner, registerPeriod);
        
        lockingAmounts[tokenId].amount = lockingAmount;
        lockingAmounts[tokenId].owner = owner;
        lockedAmountSum = lockedAmountSum + lockingAmount;

        emit NameRegistered(name, label, owner, cost, expires);

        // Refund any extra payment
        if(msg.value > cost + lockingAmount) {
            payable(msg.sender).transfer(msg.value - cost - lockingAmount);
        }
    }

    /**
     * @dev Renew specified name on registerPeriod
     * @param name Name that should be renew
     */
    function renew(string calldata name) external payable {
        uint cost = rentPrice(name);
        require(msg.value >= cost, "VanityNameController: User doesn't send enough value");

        bytes32 label = keccak256(bytes(name));
        uint expires = registrar.renew(uint256(label), registerPeriod);

        if(msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }

        emit NameRenewed(name, label, cost, expires);
    }

    function _consumeCommitment(string memory name, bytes32 commitment) internal returns (uint256) {
        // Require a valid commitment
        require(commitments[commitment] + minCommitmentAge <= block.timestamp, "VanityNameController: Min commitment age isn't passed");

        // If the commitment is too old, or the name is registered, stop
        require(commitments[commitment] + maxCommitmentAge > block.timestamp, "VanityNameController: Max commitment age had passed");
        require(available(name), "VanityNameController: Name is not available");

        delete(commitments[commitment]);

        uint cost = rentPrice(name);
        require(msg.value >= cost + lockingAmount, "VanityNameController: User doesn't send enough value");

        return cost;
    }

    function _unlockedAmount(uint256 tokenId) private {
        uint256 amountForUnlock = lockingAmounts[tokenId].amount;
        address previousLockingAmountOwner = lockingAmounts[tokenId].owner;
        unlockedAmounts[previousLockingAmountOwner] = unlockedAmounts[previousLockingAmountOwner] + amountForUnlock;
        lockingAmounts[tokenId].amount = 0;
        lockingAmounts[tokenId].owner = address(0x0);
        lockedAmountSum = lockedAmountSum - amountForUnlock;
    }
}
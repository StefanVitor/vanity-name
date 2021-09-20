// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract VanityNameRegistrar is Ownable, ERC721{

    // Address of controller which can transfer, register and renew token (vanity names)
    address private controller; 

    // Period in which user could rebuy name, and other users couldn't buy that name (and name is expired)
    uint256 public gracePeriod;

    mapping (uint256 => uint256) expiries;

    event ControllerChanged(address indexed controller);
    event GracePeriodChanged(uint256 indexed gracePeriod);
    event NameRegistered(uint256 indexed id, address indexed owner, uint expires);
    event NameRenewed(uint256 indexed id, uint expires);

    modifier onlyController {
        require(controller == msg.sender, "VanityNameRegistrar: Sender is not controller");
        _;
    }

    /**
     * @dev Initializer for VanityNameRegistrar
     * @param _gracePeriod Period in which user could rebuy name, and other users couldn't buy that name (and name is expired)
     */
    constructor(uint256 _gracePeriod) ERC721("AdvancedBlockchain", "ABAG")  {
        gracePeriod = _gracePeriod;
    }

    /**
     * @dev Setter for controller variable
     * @param _controller address of controller which can transfer, register and renew token (vanity names)
     */
    function setController(address _controller) external onlyOwner {
        controller = _controller;
        
        emit ControllerChanged(_controller);
    }

    /**
     * @dev Setter for gracePeriod variable
     * @param _gracePeriod Period in which user could rebuy name, and other users couldn't buy that name (and name is expired)
     */
    function setGracePeriod(uint256 _gracePeriod) external onlyOwner {
        gracePeriod = _gracePeriod;

        emit GracePeriodChanged(_gracePeriod);
    }


    /**
     * @dev Check expiration timestamp for specified id
     * @param id Token ID
     * @return The expiration timestamp of the specified id.
     */
    function nameExpires(uint256 id) external view returns(uint) {
        return expiries[id];
    }

    /**
     * _isApprovedOrOwner which calls ownerOf(tokenId) and takes grace period into consideration instead of ERC721.ownerOf(tokenId);
     * @dev Returns whether the given spender can transfer a given token ID
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether the msg.sender is approved for the given token ID,
     *    is an operator of the owner, or is the owner of the token
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Gets the owner of the specified token ID. Names become unowned
     *      when their registration expires.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        require(expiries[tokenId] > block.timestamp);
        return super.ownerOf(tokenId);
    }

    /**
     * @dev Check is specified id available for registration
     * @param id Token ID
     * @return Returns true iff the specified name is available for registration
     */
    function available(uint256 id) public view returns (bool) {
        // Not available if it's registered here or in its grace period.
        return expiries[id] + gracePeriod < block.timestamp;
    }

    /**
     * @dev Function that register name which is represented as token id
     * @param id Token ID
     * @param owner Owner of name (token)
     * @param duration Period for how long name will be register for that owner
     * @return Returns until that name is register
     */
    function register(uint256 id, address owner, uint duration) external onlyController returns(uint) {
        require(available(id), "VanityNameRegistrar: Id is not available");

        expiries[id] = block.timestamp + duration;
        if(_exists(id)) {
            // Name was previously owned, and expired
            _burn(id);
        }
        _mint(owner, id);

        emit NameRegistered(id, owner, block.timestamp + duration);

        return block.timestamp + duration;
    }

    /**
     * @dev Function that renew name which is currently not expiried or it is in grace period
     * @param id Token ID
     * @param duration Period for how long name will be register for that user
     * @return Returns until that name is register
     */
    function renew(uint256 id, uint duration) external onlyController returns(uint) {
        require(expiries[id] + gracePeriod >= block.timestamp, "VanityNameRegistrar: Name must be registered here or in grace period"); // Name must be registered here or in grace period

        expiries[id] += duration;
        emit NameRenewed(id, expiries[id]);
        return expiries[id];
    }
}
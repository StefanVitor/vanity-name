// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/StringUtils.sol";

// VanityNamesPrices sets a price
contract VanityNamePrices is Ownable{
    using StringUtils for *;

    // Rent in base price by length. Element 0 is for 1-length names, and so on.
    uint[] public rentPrices;

    event RentPriceChanged(uint[] prices);

     /**
     * @dev Initializer for VanityNamePrices
     * @param _rentPrices The price array. Each element corresponds to a specific
     *                    name length; names longer than the length of the array
     *                    default to the price of the last element. Values are
     *                    in tfuelWei per seconds.
     */
    constructor(uint[] memory _rentPrices) {
        setPrices(_rentPrices);
    }

    /**
     * @dev Get price for specified name
     * @param name Name for which function return price
     */
    function price(string calldata name) external view returns (uint) {
        uint len = name.strlen();
        if (len > rentPrices.length) {
            len = rentPrices.length;
        }
        require(len > 0, "VanityNamePrices: Name length is not greater than 0");
        return rentPrices[len - 1];
    }
    
    /**
     * @dev Sets rent prices.
     * @param _rentPrices The price array. Each element corresponds to a specific
     *                    name length; names longer than the length of the array
     *                    default to the price of the last element. Values are
     *                    in tfuelWei per seconds.
     */
    function setPrices(uint[] memory _rentPrices) public onlyOwner {
        rentPrices = _rentPrices;
        emit RentPriceChanged(_rentPrices);
    }
}
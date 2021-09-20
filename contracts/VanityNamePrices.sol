// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/PriceOracle.sol";
import "./libraries/StringUtils.sol";

// VanityNamesPrices sets a price
contract VanityNamePrices is Ownable, PriceOracle{
    using StringUtils for *;

    // Rent in base price by length. Element 0 is for 1-length names, and so on.
    uint[] public rentPrices;

    bytes4 constant private INTERFACE_META_ID = bytes4(keccak256("supportsInterface(bytes4)"));
    bytes4 constant private PRICE_ORACLE = bytes4(keccak256("price(string)"));

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
    function price(string calldata name) external override view returns (uint) {
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

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return interfaceID == INTERFACE_META_ID || interfaceID == PRICE_ORACLE;
    }
}
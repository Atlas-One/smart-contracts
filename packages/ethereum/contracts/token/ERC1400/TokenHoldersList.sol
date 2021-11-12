// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC1400.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

abstract contract TokenHoldersList is ERC1400 {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal tokenHolders;

    function tokenHolder(uint256 index) public view returns (address) {
        return tokenHolders.at(index);
    }

    function tokenHoldersCount() public view returns (uint256) {
        return tokenHolders.length();
    }

    function _afterTokenTransfer(
        bytes32, /* partition */
        address, /* operator */
        address from,
        address to,
        uint256, /* value */
        bytes memory, /* data */
        bytes memory /* operatorData */
    ) internal virtual override {
        if (to == address(0)) {
            if (_balances[from] > 0) {
                tokenHolders.remove(from);
            }
        } else if (from == address(0)) {
            tokenHolders.add(to);
        } else {
            if (_balances[from] > 0) {
                tokenHolders.remove(from);
            }
            tokenHolders.add(to);
        }
    }
}

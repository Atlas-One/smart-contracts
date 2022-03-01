// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC1400Roles.sol";
import "./Administrable.sol";

abstract contract ERC1400Administrable is Administrable, ERC1400Roles {
    function _onlyController(address account) internal view {
        require(
            hasRole(CONTROLLER_ROLE, account) || hasRole(ADMIN_ROLE, account),
            "58" // 0x58	invalid operator (transfer agent)
        );
    }

    function _onlyMinter(address account) internal view {
        require(
            hasRole(MINTER_ROLE, account) || hasRole(ADMIN_ROLE, account),
            "58" // 0x58	invalid operator (transfer agent)
        );
    }

    function _onlyBurner(address account) internal view {
        require(
            hasRole(BURNER_ROLE, account) || hasRole(ADMIN_ROLE, account),
            "58" // 0x58	invalid operator (transfer agent)
        );
    }

    function _onlyPartitioner(address account) internal view {
        require(
            hasRole(PARTITIONER_ROLE, account) || hasRole(ADMIN_ROLE, account),
            "58" // 0x58	transfers halted (contract paused)
        );
    }

    function _onlyPauser(address account) internal view {
        require(
            hasRole(PAUSER_ROLE, account) || hasRole(ADMIN_ROLE, account),
            "54" // 0x54	transfers halted (contract paused)
        );
    }

    /**
     * @dev Check if a status code represents success (ie: 0x*1)
     * @param status Binary ERC-1066 status code
     * @return successful A boolean representing if the status code represents success
     */
    function _isSuccess(bytes1 status) internal pure returns (bool successful) {
        return (status & 0x0F) == 0x01;
    }

    uint256[50] private __gap;
}

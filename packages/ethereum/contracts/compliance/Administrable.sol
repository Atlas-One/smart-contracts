// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Roles.sol";
import "../interface/IERC1400Validator.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Administrable is AccessControl, Roles {
    function _onlyAdmin(address account) internal view {
        require(
            hasRole(ADMIN_ROLE, account),
            "58" // 0x58	invalid operator (transfer agent)
        );
    }

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
            hasRole(BURNER_ROLE, account) ||
                hasRole(CONTROLLER_ROLE, account) ||
                hasRole(ADMIN_ROLE, account),
            "58" // 0x58	invalid operator (transfer agent)
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
}

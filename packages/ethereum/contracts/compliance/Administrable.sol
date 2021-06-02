// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Roles.sol";
import "../interface/IERC1400Validator.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Administrable is AccessControl, Roles {
    modifier onlyAdmin {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "58" // 0x58	invalid operator (transfer agent)
        );
        _;
    }
    modifier onlyController {
        require(
            hasRole(CONTROLLER_ROLE, msg.sender) ||
                hasRole(ADMIN_ROLE, msg.sender),
            "58" // 0x58	invalid operator (transfer agent)
        );
        _;
    }
    modifier onlyMinter {
        require(
            hasRole(MINTER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender),
            "58" // 0x58	invalid operator (transfer agent)
        );
        _;
    }
    modifier onlyBurner {
        require(
            hasRole(BURNER_ROLE, msg.sender) ||
                hasRole(CONTROLLER_ROLE, msg.sender) ||
                hasRole(ADMIN_ROLE, msg.sender),
            "58" // 0x58	invalid operator (transfer agent)
        );
        _;
    }
    modifier onlyPauser {
        require(
            hasRole(PAUSER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender),
            "54" // 0x54	transfers halted (contract paused)
        );
        _;
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

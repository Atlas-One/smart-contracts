// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../interface/IERC1400Validator.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Administrable is AccessControl {
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    // keccak256("CONTROLLER_ROLE")
    bytes32 public constant CONTROLLER_ROLE =
        0x7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c570223357;

    // keccak256("BURNER_ROLE")
    bytes32 public constant BURNER_ROLE =
        0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848;

    // keccak256("MINTER_ROLE")
    bytes32 public constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    // keccak256("PAUSER_ROLE")
    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;

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

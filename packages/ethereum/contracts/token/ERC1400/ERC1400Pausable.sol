// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC1400.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

abstract contract ERC1400Pausable is ERC1400, Pausable {
    // keccak256("PAUSER_ROLE")
    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;

    constructor(address[] memory pausers) {
        for (uint256 i = 0; i < pausers.length; i++) {
            _setupRole(PAUSER_ROLE, pausers[i]);
        }
    }

    /**
     * @notice freezes transfers
     */
    function pause() public {
        _onlyPauser(msg.sender);
        _pause();
    }

    /**
     * @notice unfreeze transfers
     */
    function resume() public {
        _onlyPauser(msg.sender);
        _unpause();
    }

    function _onlyPauser(address account) internal view {
        require(
            hasRole(PAUSER_ROLE, account) || hasRole(ADMIN_ROLE, account),
            "54" // 0x54	transfers halted (contract paused)
        );
    }

    // reduce contract size
    // function _canTransferByPartition(
    //     bytes32 partition,
    //     address operator,
    //     address from,
    //     address to,
    //     uint256 value,
    //     bytes memory data
    // )
    //     internal
    //     view
    //     virtual
    //     override
    //     returns (bytes1 statusCode, bytes32 appCode)
    // {
    //     if (!paused() || hasRole(PAUSER_ROLE, _msgSender())) {
    //         return (bytes1(0x54), bytes32(0)); // transfers halted (contract paused)
    //     }

    //     return
    //         super._canTransferByPartition(
    //             partition,
    //             operator,
    //             from,
    //             to,
    //             value,
    //             data
    //         );
    // }

    function _beforeTokenTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal virtual override {
        // When paused
        // Controllers can still perform transactions
        require(!paused() || _isController(_msgSender()), "paused");

        super._beforeTokenTransfer(
            partition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );
    }
}

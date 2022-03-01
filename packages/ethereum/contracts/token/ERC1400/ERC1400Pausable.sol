// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC1400.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

abstract contract ERC1400Pausable is ERC1400, Pausable {
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

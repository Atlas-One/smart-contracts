// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../token/ERC1400/ERC1400Batch.sol";
import "../token/ERC1400/ERC1400Pausable.sol";
import "../token/ERC1400/ERC1400Snapshot.sol";
import "../token/ERC1400/ERC1400_ERC777Compatible.sol";
import "../token/ERC1400/TokenHoldersList.sol";

contract ERC1400WithIntrospection is
    ERC1400_ERC777Compatible,
    ERC1400Pausable,
    ERC1400Batch,
    ERC1400Snapshot,
    TokenHoldersList
{
    constructor(
        string memory name,
        string memory symbol,
        uint256 granularity,
        bytes32[] memory defaultPartitions,
        address[] memory controllers,
        address[] memory validators,
        address vestingEscrowWallet
    )
        public
        ERC1400_ERC777Compatible(
            name,
            symbol,
            granularity,
            defaultPartitions,
            controllers,
            validators
        )
    {
        if (vestingEscrowWallet != address(0)) {
            _setupRole(MINTER_ROLE, vestingEscrowWallet);
            _setupRole(BURNER_ROLE, vestingEscrowWallet);
        }
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
    //     override(ERC1400, ERC1400Pausable)
    //     returns (bytes1, bytes32)
    // {
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
    )
        internal
        virtual
        override(
            ERC1400,
            ERC1400Pausable,
            ERC1400_ERC777Compatible,
            ERC1400Snapshot
        )
    {
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

    function _afterTokenTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    )
        internal
        virtual
        override(ERC1400, ERC1400_ERC777Compatible, TokenHoldersList)
    {
        super._afterTokenTransfer(
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

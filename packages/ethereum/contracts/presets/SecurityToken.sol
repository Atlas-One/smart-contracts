// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../token/ERC1400/ERC1400Batch.sol";
import "../token/ERC1400/ERC1400Pausable.sol";
import "../token/ERC1400/ERC1400_ERC20Compatible.sol";

contract SecurityToken is
    ERC1400_ERC20Compatible,
    ERC1400Pausable,
    ERC1400Batch
{
    constructor(
        string memory name,
        string memory symbol,
        uint256 granularity,
        uint8 decimals,
        bytes32[] memory defaultPartitions,
        address[] memory admins,
        address[] memory controllers,
        address[] memory validators,
        address[] memory burners,
        address[] memory minters,
        address[] memory pausers,
        address[] memory partitioners
    )
        public
        ERC1400_ERC20Compatible(
            name,
            symbol,
            granularity,
            decimals,
            defaultPartitions,
            admins,
            controllers,
            validators,
            burners,
            minters,
            pausers,
            partitioners
        )
    {}

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
    ) internal virtual override(ERC1400, ERC1400Pausable) {
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
    ) internal virtual override(ERC1400, ERC1400_ERC20Compatible) {
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

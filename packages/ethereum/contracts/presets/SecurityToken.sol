// SPDX-License-Identifier: args.MIT

pragma solidity ^0.8.0;

import "../token/ERC1400/ERC1400Batch.sol";
import "../token/ERC1400/ERC1400Pausable.sol";
import "../token/ERC1400/ERC1400_ERC20Compatible.sol";

struct SecurityTokenConstructorArgs {
    string name;
    string symbol;
    uint256 granularity;
    uint8 decimals;
    bytes32[] defaultPartitions;
    address[] admins;
    address[] controllers;
    address[] validators;
    address[] burners;
    address[] minters;
    address[] pausers;
    address[] partitioners;
}

contract SecurityToken is
    ERC1400_ERC20Compatible,
    ERC1400Pausable,
    ERC1400Batch
{
    constructor(SecurityTokenConstructorArgs memory args)
        ERC1400Pausable(args.pausers)
        ERC1400_ERC20Compatible(
            ERC1400ConstructorArgs({
                name: args.name,
                symbol: args.symbol,
                granularity: args.granularity,
                decimals: args.decimals,
                defaultPartitions: args.defaultPartitions,
                admins: args.admins,
                controllers: args.controllers,
                validators: args.validators,
                burners: args.burners,
                minters: args.minters,
                partitioners: args.partitioners
            })
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

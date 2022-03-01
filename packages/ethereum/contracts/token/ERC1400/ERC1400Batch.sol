// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC1400.sol";
import "./ERC1400Pausable.sol";

abstract contract ERC1400Batch is ERC1400 {
    /**
     * @param account account or contract address
     * @param roles Roles to grant.
     */
    function grantRoles(address account, bytes32[] calldata roles) external {
        for (uint256 i = 0; i < roles.length; i++) {
            grantRole(roles[i], account);
        }
    }

    /**
     * @param account Contract address.
     * @param roles Roles to revoke.
     */
    function revokeRoles(address account, bytes32[] calldata roles) external {
        for (uint256 i = 0; i < roles.length; i++) {
            revokeRole(roles[i], account);
        }
    }

    /**
     * @dev Issue tokens to multiple beneficiaries.
     * @param beneficiaries List of addresses for which we want to issue tokens.
     * @param amounts List of number of tokens to be issued to tokenHolder.
     * @param partitions List of token partitions to issue tokens to.
     */
    function issueMultiple(
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        bytes32[] calldata partitions,
        bytes calldata data
    ) external {
        _onlyIssuable();
        _onlyMinter(msg.sender);
        require(beneficiaries.length == amounts.length);
        require(beneficiaries.length == partitions.length);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _issueByPartition(
                partitions[0],
                msg.sender,
                beneficiaries[i],
                amounts[i],
                data
            );
        }
    }

    /**
     * @dev Burn/Redeem the amount of tokens from the specific address
     * @param holders List of addresses for which we want to issue tokens.
     * @param amounts List of number of tokens to be issued to tokenHolder.
     * @param partitions List of token partitions to issue tokens to.
     */
    function redeemMultiple(
        address[] calldata holders,
        uint256[] calldata amounts,
        bytes32[] calldata partitions,
        bytes calldata data
    ) external {
        _onlyBurner(msg.sender);

        require(holders.length == amounts.length);
        require(holders.length == partitions.length);

        for (uint256 i = 0; i < holders.length; i++) {
            _redeemByPartition(
                partitions[i],
                msg.sender,
                holders[i],
                amounts[i],
                data,
                ""
            );
        }
    }
}

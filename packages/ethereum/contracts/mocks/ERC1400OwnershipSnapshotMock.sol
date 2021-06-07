// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../token/ERC1400/ERC1400OwnershipSnapshot.sol";

contract ERC1400OwnershipSnapshotMock is ERC1400OwnershipSnapshot {
    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance,
        bytes32[] memory defaultPartitions,
        address[] memory admins,
        address[] memory controllers,
        address[] memory validators,
        address[] memory burners,
        address[] memory minters,
        address[] memory pausers
    )
        public
        ERC1400(
            name,
            symbol,
            1,
            defaultPartitions,
            admins,
            controllers,
            validators,
            burners,
            minters,
            pausers
        )
    {
        _issueByPartition(
            "issued",
            msg.sender,
            initialAccount,
            initialBalance,
            ""
        );
    }

    function mint(address account, uint256 amount) public {
        _issueByPartition("issued", msg.sender, account, amount, "");
    }

    function burn(address account, uint256 amount) public {
        _issueByPartition("issued", msg.sender, account, amount, "");
    }
}

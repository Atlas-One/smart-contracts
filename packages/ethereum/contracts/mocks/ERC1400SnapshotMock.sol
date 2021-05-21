// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../token/ERC1400/ERC1400Snapshot.sol";

contract ERC1400SnapshotMock is ERC1400Snapshot {
    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance,
        bytes32[] memory defaultPartitions,
        address[] memory controllers,
        address[] memory validators
    ) public 
        ERC1400(
            name,
            symbol,
            1,
            defaultPartitions,
            controllers,
            validators
        ) {
        _issueByPartition(
            "issued",
            msg.sender,
            initialAccount,
            initialBalance,
            ""
        );
    }

    function mint(address account, uint256 amount) public {
        _issueByPartition(
            "issued",
            msg.sender,
            account,
            amount,
            ""
        );
    }

    function burn(address account, uint256 amount) public {
        _issueByPartition(
            "issued",
            msg.sender,
            account,
            amount,
            ""
        );
    }
}

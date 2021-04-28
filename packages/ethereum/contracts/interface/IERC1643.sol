// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

// @title IERC1643 Document Management (part of the ERC1400 Security Token Standards)
/// @dev See https://github.com/SecurityTokenStandard/EIP-Spec

interface IERC1643 {
    // Document Management
    function getDocument(bytes32 _name)
        external
        view
        returns (string memory, bytes32);

    function setDocument(
        bytes32 _name,
        string calldata _uri,
        bytes32 _documentHash
    ) external;

    function removeDocument(bytes32 _name) external;

    // Document Events
    event DocumentRemoved(
        bytes32 indexed _name,
        string _uri,
        bytes32 _documentHash
    );
    event DocumentUpdated(
        bytes32 indexed _name,
        string _uri,
        bytes32 _documentHash
    );
}

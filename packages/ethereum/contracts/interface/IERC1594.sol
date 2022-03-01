// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Standard Interface of ERC1594
 */
interface IERC1594 {
    // Transfers
    function transferWithData(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external;

    function transferFromWithData(
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external;

    // Token Issuance
    function isIssuable() external view returns (bool);

    // Issues to the first partition in the unlocked partitions list as a default partition
    function issue(
        address _tokenHolder,
        uint256 _value,
        bytes calldata _data
    ) external;

    // redeeming effectively burns tokens
    // the redemption from is handled off-chain
    function redeem(uint256 _value, bytes calldata _data) external;

    // redeeming effectively burns tokens
    // the redemption from is handled off-chain
    function redeemFrom(
        address _tokenHolder,
        uint256 _value,
        bytes calldata _data
    ) external;

    // Transfer Validity
    // omitted for contract size
    // function canTransfer(
    //     address _to,
    //     uint256 _value,
    //     bytes calldata _data
    // ) external view returns (bytes1, bytes32);

    // omitted for contract size
    // function canTransferFrom(
    //     address _from,
    //     address _to,
    //     uint256 _value,
    //     bytes calldata _data
    // ) external view returns (bytes1, bytes32);

    // Issuance / Redemption Events
    event Issued(
        address indexed operator,
        address indexed to,
        uint256 value,
        bytes data
    );
    event Redeemed(
        address indexed operator,
        address indexed from,
        uint256 value,
        bytes data
    );
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

interface IERC1400Validator {
    /**
     * @return ESC (Ethereum Status Code) following the EIP-1066 standard
     * @return Application specific reason codes with additional details
     */
    function validateTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata operatorData
    ) external view returns (bytes1, bytes32);
}

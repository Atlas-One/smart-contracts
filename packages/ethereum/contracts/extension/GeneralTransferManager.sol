// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../compliance/Allowlist.sol";
import "../compliance/Administrable.sol";

import "../interface/IERC1644.sol";
import "../interface/IERC1400Validator.sol";

import "../token/ERC1400/PartitionDestination.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// import "../utils/OperatorData.sol";

// Current implementation checks:
// - only burner can burn
// - only controller can switch partitions
// - address is in the allowed list
// - address is not in the blocked list
contract GeneralTransferManager is
    Context,
    Administrable,
    Allowlist,
    IERC1400Validator,
    PartitionDestination
{
    constructor() public {
        _setupRole(ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Only the token contract should call this function.
     * The standard provides an on-chain function to determine whether a transfer will succeed,
     * and return details indicating the reason if the transfer is not valid.
     * @param operator The address performing the transfer.
     * @param from The address from whom the tokens get transferred.
     * @param to The address to which to transfer tokens to.
     * @param partition The partition from which to transfer tokens.
     * param value The amount of tokens to transfer from `_partition`
     * param data Additional data attached to the transfer of tokens
     * param operatorData Information attached to the redemption, by the operator.
     * @return statusCode ESC (Ethereum Status Code) following the EIP-1066 standard
     * @return appCode Application specific reason codes with additional details
     */
    function validateTransfer(
        bytes calldata, /*  payload */
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256, /* value */
        bytes calldata, /* data */
        bytes calldata /*  operatorData */
    ) external view override returns (bytes1, bytes32) {
        // *IMPORTANT* for compliance
        return _canTransferByAllowlist(operator, partition, from, to);
    }

    /**
     * @notice The standard provides an on-chain function to determine an address KYC
     * @param operator The address performing the transfer.
     * @param partition The partition from which to transfer tokens.
     * @param from The address from whom the tokens get transferred.
     * @param to The address to which to transfer tokens to.
     * @return statusCode ESC (Ethereum Status Code) following the EIP-1066 standard
     * @return appCode Application specific reason codes with additional details
     */
    function _canTransferByAllowlist(
        address operator,
        bytes32 partition,
        address from,
        address to
    ) internal view returns (bytes1, bytes32) {
        // Controller should be able to:
        // - move tokens *from* an address that is not in the allowed list
        // - move tokens *from* a blocklisted address
        if (
            (from != address(0) &&
                !isAllowlisted(from) &&
                !_isController(operator, partition))
        ) {
            return (bytes1(0x50), bytes32(0));
        }
        // Not even the controller should be able to an unwhitlisted address
        if (to != address(0) && !isAllowlisted(to)) {
            return (bytes1(0x50), bytes32(0));
        }
        if (
            (from != address(0) &&
                isBlocklisted(from) &&
                !_isController(operator, partition))
        ) {
            return (bytes1(0x50), bytes32(0));
        }
        // Not even the controller should be able to send to a blocklisted address
        if (to != address(0) && isBlocklisted(to)) {
            return (bytes1(0x50), bytes32(0));
        }

        return (bytes1(0x51), bytes32(0));
    }

    /**
     * @dev _msgSender() is the token contract
     */
    function _isController(address operator, bytes32 partition)
        internal
        view
        returns (bool)
    {
        address securityToken = _msgSender();
        return
            IERC1644(securityToken).isControllable() &&
            (// is administrator/owner
            AccessControl(securityToken).hasRole(ADMIN_ROLE, operator) ||
                // is controller for all tokens and partitions
                AccessControl(securityToken).hasRole(
                    CONTROLLER_ROLE,
                    operator
                ) ||
                // is controller for tokens in this partition
                AccessControl(securityToken).hasRole(
                    keccak256(abi.encodePacked(partition, CONTROLLER_ROLE)),
                    operator
                ));
    }
}

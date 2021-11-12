// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../compliance/Roles.sol";
import "../compliance/Allowlist.sol";

import "../interface/IERC1644.sol";
import "../interface/IERC1400Validator.sol";

import "../token/ERC1400/PartitionDestination.sol";

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

// Current implementation checks:
// - only burner can burn
// - only controller can switch partitions
// - address is in the allowed list
// - address is not in the blocked list
contract GeneralTransferManager is
    IERC1400Validator,
    Initializable,
    Roles,
    Allowlist,
    PartitionDestination
{
    function initialize() public virtual initializer {
        __AccessControl_init();
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
        address securityToken = _msgSender();
        // Controller should be able to:
        // - move tokens *from* an address that is not in the allowed list
        // - move tokens *from* a blocklisted address
        if (
            (from != address(0) &&
                !isAllowed(from, securityToken) &&
                !_isController(operator, partition, securityToken))
        ) {
            return (bytes1(0x50), bytes32(0));
        }
        // Not even the controller should be able to an unwhitlisted address
        if (to != address(0) && !isAllowed(to, securityToken)) {
            return (bytes1(0x50), bytes32(0));
        }
        if (
            (from != address(0) &&
                isBlocked(from) &&
                !_isController(operator, partition, securityToken))
        ) {
            return (bytes1(0x50), bytes32(0));
        }
        // Not even the controller should be able to send to a blocklisted address
        if (to != address(0) && isBlocked(to)) {
            return (bytes1(0x50), bytes32(0));
        }

        return (bytes1(0x51), bytes32(0));
    }

    /**
     * @dev _msgSender() is the token contract
     */
    function _isController(
        address operator,
        bytes32 partition,
        address token
    ) internal view returns (bool) {
        return
            IERC1644(token).isControllable() &&
            (// is administrator/owner
            AccessControlUpgradeable(token).hasRole(ADMIN_ROLE, operator) ||
                // is controller for all tokens and partitions
                AccessControlUpgradeable(token).hasRole(
                    CONTROLLER_ROLE,
                    operator
                ) ||
                // is controller for tokens in this partition
                AccessControlUpgradeable(token).hasRole(
                    keccak256(abi.encodePacked(partition, CONTROLLER_ROLE)),
                    operator
                ));
    }

    uint256[50] private __gap;
}

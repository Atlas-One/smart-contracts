// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../compliance/Whitelist.sol";
import "../compliance/AdministrableUpgradeable.sol";

import "../interface/IERC1644.sol";
import "../interface/IValidator.sol";

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

// Current implementation checks:
// - only burner can burn
// - only controller can switch partitions
// - address is in the allowed list
// - address is not in the blocked list
contract WhitelistValidator is
    IValidator,
    Initializable,
    AdministrableUpgradeable
{
    Whitelist public whitelistContract;

    function initialize(address _whitelistContract) public virtual initializer {
        __AccessControl_init();
        _setupRole(ADMIN_ROLE, msg.sender);

        whitelistContract = Whitelist(_whitelistContract);
    }

    /**
     * @notice Only the token contract should call this function.
     * The standard provides an on-chain function to determine whether a transfer will succeed,
     * and return details indicating the reason if the transfer is not valid.
     * @param partition The partition from which to transfer tokens.
     * @param operator The address performing the transfer.
     * @param from The address from whom the tokens get transferred.
     * @param to The address to which to transfer tokens to.
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
        IERC1644 token = IERC1644(msg.sender);
        bool isControllerForPartition = token.isControllerForPartition(
            partition,
            operator
        );
        // Controller can move tokens out of a unwhitelisted address
        if (
            (from != address(0) &&
                !whitelistContract.isWhitelisted(from) &&
                !isControllerForPartition)
        ) {
            return (bytes1(0x50), bytes32(0));
        }
        // Controller can move tokens out of a blacklisted address
        if (
            from != address(0) &&
            whitelistContract.isBlacklisted(from) &&
            !isControllerForPartition
        ) {
            return (bytes1(0x50), bytes32(0));
        }
        // Allow only moving tokens to an address that is whitelisted
        if ((to != address(0) && !whitelistContract.isWhitelisted(to))) {
            return (bytes1(0x50), bytes32(0));
        }
        // Allow only moving tokens to an address that is not blacklisted
        if (to != address(0) && whitelistContract.isBlacklisted(to)) {
            return (bytes1(0x50), bytes32(0));
        }

        return (bytes1(0x51), bytes32(0));
    }

    uint256[50] private __gap;
}

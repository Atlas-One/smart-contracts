// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../compliance/Identity.sol";
import "../compliance/AdministrableUpgradeable.sol";

import "../interface/IERC1644.sol";
import "../interface/IValidator.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Current implementation checks:
// - only burner can burn
// - only controller can switch partitions
// - address is in the allowed list
// - address is not in the blocked list
contract IdentityValidator is
    IValidator,
    Initializable,
    AdministrableUpgradeable
{
    Identity public identityContract;

    function initialize(address _identityContract) public virtual initializer {
        __AccessControl_init();
        _setupRole(ADMIN_ROLE, msg.sender);

        identityContract = Identity(_identityContract);
    }

    /**
     * @notice Only the token contract should call this function.
     * The standard provides an on-chain function to determine whether a transfer will succeed,
     * and return details indicating the reason if the transfer is not valid.
     * @param partition The partition from which to transfer tokens.
     * @param operator The address performing the transfer.
     * from The address from whom the tokens get transferred.
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
        address, /* from */
        address to,
        uint256, /* value */
        bytes calldata, /* data */
        bytes calldata /*  operatorData */
    ) external view override returns (bytes1, bytes32) {
        IERC1644 token = IERC1644(msg.sender);
        // bytes32 fromId = identityContract.accountIdentity(from);
        bytes32 toId = identityContract.accountIdentity(to);

        if (
            to != address(0) &&
            (!identityContract.identityClaims(toId, "ON") ||
                token.isControllerForPartition(partition, operator))
        ) {
            return (bytes1(0x50), bytes32(0));
        }

        return (bytes1(0x51), bytes32(0));
    }

    uint256[50] private __gap;
}

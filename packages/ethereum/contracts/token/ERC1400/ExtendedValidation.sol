// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../interface/IERC1400Validator.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// To handle extendend validations
abstract contract ExtendedValidation is AccessControl {
    // keccak256("VALIDATOR")
    bytes32 public constant VALIDATOR_ROLE =
        0x21702c8af46127c7fa207f89d0b0a8441bb32959a0ac7df790e9ab1a25c98926;

    /**
     * @dev Check against custom validations calling contracts implementing the IERC1400Validator given the VALIDATOR_ROLE
     * @param partition Name of the partition (bytes32 to be left empty for transfers where partition is not specified).
     * @param operator Address which triggered the balance decrease (through transfer or redemption).
     * @param from Token holder.
     * @param to Token recipient for a transfer and 0x for a redemption.
     * @param value Number of tokens the token holder balance is decreased by.
     * @param data Extra information.
     * @param operatorData Extra information, attached by the operator (if any).
     */
    function _validateTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal view returns (bytes1 statusCode, bytes32 appCode) {
        for (
            uint256 index = 0;
            index < getRoleMemberCount(VALIDATOR_ROLE);
            index++
        ) {
            address extention = getRoleMember(VALIDATOR_ROLE, index);

            (statusCode, appCode) = IERC1400Validator(extention)
                .validateTransfer(
                msg.data,
                partition,
                operator,
                from,
                to,
                value,
                data,
                operatorData
            );

            if ((statusCode & 0x0F) != 0x01) {
                return (statusCode, appCode);
            }
        }

        return (bytes1(0x51), bytes32(0));
    }

    function _assertValidTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal view {
        bytes1 statusCode;
        bytes32 appCode;
        (statusCode, appCode) = _validateTransfer(
            partition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );

        require((statusCode & 0x0F) == 0x01, "50");
    }
}

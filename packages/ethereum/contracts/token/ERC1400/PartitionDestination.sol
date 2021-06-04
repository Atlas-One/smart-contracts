// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

abstract contract PartitionDestination {
    /**
     * @dev Retrieve the destination partition from the 'data' field.
     * By convention, a partition change is requested ONLY when 'data' starts
     * with the flag: 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
     * When the flag is detected, the destination tranche is extracted from the
     * 32 bytes following the flag.
     * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
     * return bytes32 destination partition.
     */
    function _getDestinationPartition(bytes memory data, bytes32 fromPartition)
        internal
        pure
        returns (bytes32 toPartition)
    {
        if (data.length < 64) {
            toPartition = fromPartition;
        } else {
            bytes32 changePartitionFlag =
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
            bytes32 flag;
            assembly {
                flag := mload(add(data, 32))
            }
            if (flag == changePartitionFlag) {
                assembly {
                    toPartition := mload(add(data, 64))
                }
            } else {
                toPartition = fromPartition;
            }
        }
    }

    uint256[50] private __gap;
}

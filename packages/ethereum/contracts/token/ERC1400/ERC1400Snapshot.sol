// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC1400.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";

// Adopted from OpenZeppelin Snapshots:
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.0.0/contracts/token/ERC20/ERC20Snapshot.sol

abstract contract ERC1400Snapshot is ERC1400 {
    using SafeMath for uint256;
    using Arrays for uint256[];

    // made these public to have the option of iterating through them off chain
    uint256[] public snapshotIds;
    uint256[] public totalSupplySnapshots;
    mapping(address => uint256[]) public accountBalanceSnapshots;

    // partition snapshots
    // mapping(bytes32 => uint256[]) public totalSupplyByPartitionSnapshots;
    // mapping(address => mapping(bytes32 => uint256[])) public accountBalanceByPartitionSnapshots;

    /**
     * @dev Get the current snapshotId
     */
    function _getCurrentSnapshotId() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
     * @dev Retrieves the balance of `account` at the time `snapshotId` was created.
     */
    function balanceOfAt(address account, uint256 snapshotId)
        public
        view
        virtual
        returns (uint256)
    {
        (bool snapshotted, uint256 value) =
            _valueAt(snapshotId, accountBalanceSnapshots[account]);

        return snapshotted ? value : _balances[account];
    }

    /**
     * @dev Retrieves the total supply at the time `snapshotId` was created.
     */
    function totalSupplyAt(uint256 snapshotId)
        public
        view
        virtual
        returns (uint256)
    {
        (bool snapshotted, uint256 value) =
            _valueAt(snapshotId, totalSupplySnapshots);

        return snapshotted ? value : _totalSupply;
    }

    function _valueAt(uint256 snapshotId, uint256[] storage snapshotValues)
        private
        view
        returns (bool, uint256)
    {
        require(snapshotId > 0, "50");
        require(snapshotId <= _getCurrentSnapshotId(), "50");

        uint256 index = snapshotIds.findUpperBound(snapshotId);

        if (index == snapshotIds.length) {
            return (false, 0);
        } else {
            return (true, snapshotValues[index]);
        }
    }

    function _updateAccountSnapshot(address account) private {
        _updateSnapshot(accountBalanceSnapshots[account], _balances[account]);
    }

    function _updateTotalSupplySnapshot() private {
        _updateSnapshot(totalSupplySnapshots, _totalSupply);
    }

    function _updateSnapshot(
        uint256[] storage snapshotValues,
        uint256 currentValue
    ) private {
        uint256 currentId = _getCurrentSnapshotId();
        if (_lastSnapshotId(snapshotIds) < currentId) {
            snapshotIds.push(currentId);
            snapshotValues.push(currentValue);
        }
    }

    function _lastSnapshotId(uint256[] storage ids)
        private
        view
        returns (uint256)
    {
        if (ids.length == 0) {
            return 0;
        } else {
            return ids[ids.length - 1];
        }
    }

    function _beforeTokenTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal virtual override {
        super._beforeTokenTransfer(
            partition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );

        if (from == address(0)) {
            // mint
            _updateAccountSnapshot(to);
            _updateTotalSupplySnapshot();
        } else if (to == address(0)) {
            // burn
            _updateAccountSnapshot(from);
            _updateTotalSupplySnapshot();
        } else {
            // transfer
            _updateAccountSnapshot(from);
            _updateAccountSnapshot(to);
        }
    }
}

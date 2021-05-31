// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC1400.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

abstract contract ERC1400OwnershipSnapshot is ERC1400 {
    using SafeMath for uint256;

    struct Ownership {
        uint256 timestamp;
        uint256 amount;
    }
    mapping(address => Ownership[]) public ownerships;

    /**
     * @notice Issue tokens from default partition.
     * @param partition Name of the partition.
     * @param timestamp Owned the issued token amount from date.
     * @param account Address for which we want to issue tokens.
     * @param amount Number of tokens issued.
     * @param data Information attached to the issuance, by the issuer.
     */
    function issueOwned(
        bytes32 partition,
        uint256 timestamp,
        address account,
        uint256 amount,
        bytes calldata data
    ) external onlyMinter onlyIssuable {
        _issueByPartition(partition, msg.sender, account, amount, data);

        // modify the latest addition with the provided timestamp
        ownerships[account][ownerships[account].length - 1]
            .timestamp = timestamp;
    }

    /**
     * @notice Describes/Partitions the token amount to the different ownership periods.
     * @return durations The time in seconds holding the token amount
     * @return amounts The amount held for the respective duration
     */
    function describeOwnership(address account, uint256 amount)
        public
        view
        returns (uint256[] memory durations, uint256[] memory amounts)
    {
        uint256 size = 0;
        uint256 _remainingAmount = amount;
        for (uint256 i = 0; i < ownerships[account].length; i++) {
            Ownership storage ownership = ownerships[account][i];

            if (_remainingAmount >= ownership.amount) {
                _remainingAmount = _remainingAmount.sub(ownership.amount);
            } else {
                _remainingAmount = 0;
            }

            size++;

            if (_remainingAmount == 0) {
                break;
            }
        }
        require(_remainingAmount == 0);

        amounts = new uint256[](size);
        durations = new uint256[](size);

        _remainingAmount = amount;
        for (uint256 i = 0; i < ownerships[account].length; i++) {
            Ownership storage ownership = ownerships[account][i];

            if (_remainingAmount >= ownership.amount) {
                amounts[i] = ownership.amount;
                _remainingAmount = _remainingAmount.sub(ownership.amount);
            } else {
                amounts[i] = ownership.amount.sub(_remainingAmount);
                _remainingAmount = 0;
            }
            durations[i] = block.timestamp - ownership.timestamp;
            if (_remainingAmount == 0) {
                break;
            }
        }
        require(_remainingAmount == 0);
    }

    /**
     * @notice Captures the time when the token amount was received
     */
    function _captureOwnernship(address account, uint256 amount) private {
        ownerships[account].push(
            Ownership({amount: amount, timestamp: block.timestamp})
        );
    }

    /**
     * @notice When redeeming/burning, we burn the oldest owned tokens.
     */
    function _burnOldest(address account, uint256 amount) private {
        uint256 _remainingAmount = amount;
        for (uint256 i = 0; i < ownerships[account].length; i++) {
            _remainingAmount = _burnOwnership(
                ownerships[account][i],
                _remainingAmount
            );
            if (_remainingAmount == 0) {
                break;
            }
        }

        require(_remainingAmount == 0);
    }

    /**
     * @notice When transfering, we burn the ownership from the latest owned tokens.
     */
    function _burnLatest(address account, uint256 amount)
        private
        returns (uint256)
    {
        uint256 _remainingAmount = amount;
        for (uint256 i = ownerships[account].length; i >= 0; i--) {
            _remainingAmount = _burnOwnership(
                ownerships[account][i],
                _remainingAmount
            );

            if (_remainingAmount == 0) {
                break;
            }
        }

        require(_remainingAmount == 0);
    }

    function _burnOwnership(Ownership storage ownership, uint256 amount)
        private
        returns (uint256)
    {
        uint256 _ownedAmount = ownership.amount;
        if (amount > _ownedAmount) {
            ownership.amount = 0;

            return amount.sub(_ownedAmount);
        }

        ownership.amount = _ownedAmount.sub(amount);

        return 0;
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
            _captureOwnernship(to, value);
        } else if (to == address(0)) {
            // burn
            _burnOldest(from, value);
        } else {
            // transfer
            _burnLatest(from, value);
            _captureOwnernship(to, value);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC1400.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

abstract contract ERC1400OwnershipSnapshot is ERC1400 {
    using SafeMath for uint256;

    struct Ownership {
        uint256 amount;
        uint256 next;
        uint256 prev;
    }
    mapping(address => uint256) public initialOwnershipTimestamp;
    mapping(address => uint256) public latestOwnershipTimestamp;
    mapping(address => mapping(uint256 => Ownership)) public ownerships;

    bool private skipCaptureOwnernship = false;

    /**
     * @notice Unsorted insertion of previously owned amount at specified timestamp.
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
        require(ownerships[account][timestamp].amount == 0);
        // skip _beforeTokenTransfer hook that calls _captureOwnernship
        skipCaptureOwnernship = true;

        _issueByPartition(partition, msg.sender, account, amount, data);

        uint256 before = initialOwnershipTimestamp[account];
        while (before != 0) {
            if (before < timestamp) {
                break;
            }
            before = ownerships[account][before].next;
        }

        if (
            initialOwnershipTimestamp[account] == 0 ||
            initialOwnershipTimestamp[account] > timestamp
        ) {
            initialOwnershipTimestamp[account] = timestamp;
        }
        if (latestOwnershipTimestamp[account] < timestamp) {
            latestOwnershipTimestamp[account] = timestamp;
        }

        ownerships[account][timestamp] = Ownership({
            amount: amount,
            prev: ownerships[account][before].prev,
            next: before
        });

        if (before != 0) {
            if (ownerships[account][before].prev != 0) {
                ownerships[account][ownerships[account][before].prev]
                    .next = timestamp;
            }
            ownerships[account][before].prev = timestamp;
        }

        // resume _beforeTokenTransfer hook that calls _captureOwnernship
        skipCaptureOwnernship = false;
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

        uint256 current = initialOwnershipTimestamp[account];
        while (current != 0) {
            Ownership storage ownership = ownerships[account][current];

            if (_remainingAmount >= ownership.amount) {
                _remainingAmount = _remainingAmount.sub(ownership.amount);
            } else {
                _remainingAmount = 0;
            }

            size++;

            current = ownership.next;
            if (_remainingAmount == 0) {
                break;
            }
        }
        require(_remainingAmount == 0, "55");

        amounts = new uint256[](size);
        durations = new uint256[](size);

        _remainingAmount = amount;
        current = initialOwnershipTimestamp[account];
        uint256 i = 0;
        while (current != 0) {
            Ownership storage ownership = ownerships[account][current];

            if (_remainingAmount >= ownership.amount) {
                amounts[i] = ownership.amount;
                _remainingAmount = _remainingAmount.sub(ownership.amount);
            } else {
                amounts[i] = ownership.amount.sub(_remainingAmount);
                _remainingAmount = 0;
            }
            durations[i] = block.timestamp - current;

            i++;
            current = ownership.next;
            if (_remainingAmount == 0) {
                break;
            }
        }
        require(_remainingAmount == 0, "55");
    }

    /**
     * @notice Captures the time when the token amount was received
     */
    function _captureOwnernship(address account, uint256 amount) private {
        if (skipCaptureOwnernship == false) {
            ownerships[account][block.timestamp] = Ownership({
                amount: amount,
                prev: latestOwnershipTimestamp[account],
                next: 0
            });

            if (initialOwnershipTimestamp[account] == 0) {
                initialOwnershipTimestamp[account] = block.timestamp;
            }

            if (latestOwnershipTimestamp[account] != 0) {
                ownerships[account][latestOwnershipTimestamp[account]]
                    .next = block.timestamp;
            }

            latestOwnershipTimestamp[account] = block.timestamp;
        }
    }

    /**
     * @notice When redeeming/burning, we burn the oldest owned tokens.
     */
    function _burnOldest(address account, uint256 amount) private {
        uint256 _remainingAmount = amount;
        uint256 current = initialOwnershipTimestamp[account];
        while (current != 0) {
            _remainingAmount = _burnOwnership(
                current,
                account,
                _remainingAmount
            );

            current = ownerships[account][current].next;

            _deleteOwnership(current, account);

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
        uint256 current = latestOwnershipTimestamp[account];
        while (current != 0) {
            _remainingAmount = _burnOwnership(
                current,
                account,
                _remainingAmount
            );

            current = ownerships[account][current].prev;

            _deleteOwnership(current, account);

            if (_remainingAmount == 0) {
                break;
            }
        }

        require(_remainingAmount == 0);
    }

    function _burnOwnership(
        uint256 timestamp,
        address account,
        uint256 amount
    ) private returns (uint256) {
        Ownership storage ownership = ownerships[account][timestamp];
        uint256 _ownedAmount = ownership.amount;
        if (amount >= _ownedAmount) {
            ownership.amount = 0;

            return amount.sub(_ownedAmount);
        }

        ownership.amount = _ownedAmount.sub(amount);

        return 0;
    }

    function _deleteOwnership(uint256 timestamp, address account) private {
        Ownership storage ownership = ownerships[account][timestamp];
        if (ownership.amount == 0) {
            if (ownership.next != 0) {
                ownerships[account][ownership.next].prev = ownership.prev;
            }
            if (ownership.prev != 0) {
                ownerships[account][ownership.prev].prev = ownership.next;
            }

            delete ownerships[account][timestamp];
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

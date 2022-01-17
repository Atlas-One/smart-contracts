// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../interface/IERC1410.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

/**
 * @title Wallet for core vesting escrow functionality
 */
contract VestingEscrowMinterBurnerWallet {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private constant TOKEN_ADMIN_ROLE = 0x00;

    // schedules map
    // holder => scheduleName
    // scheduleNames should be unique per token
    mapping(address => bytes32[]) public scheduleNames;
    // token => holder => scheduleName
    // scheduleNames should be unique per token
    mapping(address => mapping(address => bytes32[]))
        public scheduleNamesPerToken;
    // holder => scheduleName
    // scheduleNames should be unique per token
    mapping(address => mapping(bytes32 => Schedule)) public schedules;

    mapping(address => EnumerableSet.AddressSet) internal _beneficiariesByToken;

    // Emit when new schedule is added
    event ScheduleAdded(
        address indexed token,
        address indexed beneficiary,
        bytes32 indexed scheduleName,
        uint256 start,
        uint256 end,
        uint256 cliff,
        uint256 vestingAmount
    );

    // Emit when new schedule is added
    event ScheduleChanged(
        address indexed token,
        address indexed beneficiary,
        bytes32 indexed scheduleName,
        uint256 start,
        uint256 end,
        uint256 cliff,
        uint256 vestingAmount
    );

    event ScheduleRevoked(
        address indexed token,
        address indexed beneficiary,
        bytes32 indexed scheduleName
    );

    event BeneficiaryChanged(
        address indexed token,
        address indexed beneficiary,
        bytes32 indexed scheduleName,
        address to
    );

    event Claimed(
        address indexed token,
        address indexed beneficiary,
        uint256 amount
    );

    struct Schedule {
        bool exists;
        address token;
        address beneficiary;
        bytes32 name;
        uint256 start;
        uint256 end;
        uint256 cliff;
        uint256 vestingAmount;
        uint256 claimedAmount;
        bool revoked;
        uint256 revokedAt;
        address revokedBy;
    }

    function beneficiaryForToken(address token, uint256 index)
        public
        view
        returns (address)
    {
        return _beneficiariesByToken[token].at(index);
    }

    function vestingSummaryForToken(address token, address beneficiary)
        public
        view
        returns (
            uint256 tVesting,
            uint256 tClaimed,
            uint256 tRevoked
        )
    {
        for (uint256 i = 0; i < scheduleNames[beneficiary].length; i++) {
            Schedule memory schedule = schedules[beneficiary][
                scheduleNames[beneficiary][i]
            ];
            if (schedule.token != token && !schedule.revoked) {
                tVesting = tVesting.add(schedule.vestingAmount);
                tClaimed = tClaimed.add(schedule.claimedAmount);
            }
            if (schedule.token != token && schedule.revoked) {
                tRevoked = tRevoked.add(
                    schedule.vestingAmount.sub(schedule.claimedAmount)
                );
            }
        }
    }

    /**
     * @notice Pushes available tokens to the beneficiary's address
     * @param beneficiary Address of the beneficiary who will receive tokens
     */
    function claimFor(address beneficiary) public {
        _transferPerSchedule(beneficiary);
    }

    /**
     * @notice Used to withdraw available tokens by beneficiary
     */
    function claim() external {
        _transferPerSchedule(msg.sender);
    }

    /**
     * @notice Adds vesting schedules for each of the beneficiary's address
     * @param token Token address
     * @param beneficiary Address of the beneficiary for whom it is scheduled
     * @param scheduleName Name of the template that will be created
     * @param vestingAmount Total number of tokens for created schedule
     * @param start Start timestamp
     * @param end End timestamp
     * @param cliff Cliff timestamp
     */
    function vest(
        address token,
        address beneficiary,
        bytes32 scheduleName,
        uint256 vestingAmount,
        uint256 start,
        uint256 end,
        uint256 cliff
    ) external {
        _vest(
            token,
            beneficiary,
            scheduleName,
            vestingAmount,
            start,
            end,
            cliff
        );

        IERC1410(token).issueByPartition(
            scheduleName,
            address(this),
            vestingAmount,
            ""
        );
    }

    /**
     * @notice Used to bulk add vesting schedules for each of beneficiary
     * @param _tokens Tokens to vest
     * @param _beneficiaries Array of the beneficiary's addresses
     * @param _scheduleNames Array of the schedule names
     * @param _vestingAmounts Array of number of tokens should be assigned to schedules
     * @param _startTimes Array of the vesting start time
     * @param _endTimes Array of the vesting end time
     * @param _cliffs Array of the vesting frequency
     */
    function vestMultiple(
        address[] memory _tokens,
        address[] memory _beneficiaries,
        bytes32[] memory _scheduleNames,
        uint256[] memory _vestingAmounts,
        uint256[] memory _startTimes,
        uint256[] memory _endTimes,
        uint256[] memory _cliffs
    ) public {
        require(
            _tokens.length == _beneficiaries.length &&
                _beneficiaries.length == _scheduleNames.length &&
                _beneficiaries.length == _startTimes.length &&
                _beneficiaries.length == _endTimes.length &&
                _beneficiaries.length == _cliffs.length &&
                _beneficiaries.length == _vestingAmounts.length,
            "Arrays sizes mismatch"
        );

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            _vest(
                _tokens[i],
                _beneficiaries[i],
                _scheduleNames[i],
                _vestingAmounts[i],
                _startTimes[i],
                _endTimes[i],
                _cliffs[i]
            );

            IERC1410(_tokens[i]).issueByPartition(
                _scheduleNames[i],
                address(this),
                _vestingAmounts[i],
                ""
            );
        }
    }

    function _vest(
        address token,
        address beneficiary,
        bytes32 scheduleName,
        uint256 vestingAmount,
        uint256 start,
        uint256 end,
        uint256 cliff
    ) internal {
        _addBeneficiary(token, beneficiary);

        if (schedules[beneficiary][scheduleName].exists) {
            _addVestingAmount(beneficiary, scheduleName, vestingAmount);
        } else {
            require(
                cliff >= start,
                "Cliff should be greater or equal to start"
            );
            require(end > start, "End should be greater than start");
            require(end > cliff, "End should be greater than cliff");

            schedules[beneficiary][scheduleName] = Schedule({
                exists: true,
                token: token,
                beneficiary: beneficiary,
                name: scheduleName,
                start: start,
                end: end,
                cliff: cliff,
                vestingAmount: vestingAmount,
                claimedAmount: 0,
                revoked: false,
                revokedAt: 0,
                revokedBy: address(0)
            });

            scheduleNames[beneficiary].push(scheduleName);
            scheduleNamesPerToken[beneficiary][token].push(scheduleName);

            emit ScheduleAdded(
                token,
                beneficiary,
                scheduleName,
                start,
                end,
                cliff,
                vestingAmount
            );
        }
    }

    /**
     * @notice Modifies vesting schedules for each of the beneficiary
     * @param to Address of the new beneficiary
     * @param scheduleName Name of the template was used for schedule creation
     */
    function changeBeneficiaryForSchedule(
        address from,
        address to,
        bytes32 scheduleName
    ) external {
        _changeBeneficiary(from, to, scheduleName);
    }

    /**
     * @notice Modifies vesting schedules for each of the beneficiary
     * @param from Address of the beneficiary for whom it is modified
     * @param to Address of the new beneficiary
     */
    function changeBeneficiaryForAllSchedules(address from, address to)
        external
    {
        for (uint256 i = 0; i < scheduleNames[from].length; i++) {
            _changeBeneficiary(from, to, scheduleNames[from][i]);
        }
    }

    function _changeBeneficiary(
        address from,
        address to,
        bytes32 scheduleName
    ) internal {
        Schedule storage schedule = _getSchedule(from, scheduleName);

        require(_isTokenAdmin(schedule.token, msg.sender));

        schedules[to][scheduleName] = Schedule({
            exists: true,
            token: schedule.token,
            beneficiary: schedule.beneficiary,
            name: schedule.name,
            start: schedule.start,
            end: schedule.end,
            cliff: schedule.cliff,
            vestingAmount: schedule.vestingAmount,
            claimedAmount: schedule.claimedAmount,
            revoked: schedule.revoked,
            revokedAt: schedule.revokedAt,
            revokedBy: schedule.revokedBy
        });

        delete schedules[from][scheduleName];

        emit BeneficiaryChanged(
            schedules[to][scheduleName].token,
            from,
            scheduleName,
            to
        );
    }

    function _addVestingAmount(
        address beneficiary,
        bytes32 scheduleName,
        uint256 amount
    ) internal {
        Schedule storage schedule = _getSchedule(beneficiary, scheduleName);

        schedule.vestingAmount = schedule.vestingAmount.add(amount);

        emit ScheduleChanged(
            schedule.token,
            schedule.beneficiary,
            schedule.name,
            schedule.start,
            schedule.end,
            schedule.cliff,
            schedule.vestingAmount
        );
    }

    function revokeSchedule(
        address[] calldata beneficiaries,
        bytes32[] calldata revokeSchedules
    ) external {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            // Transfer any unclaimed funds
            _transfer(beneficiaries[i], revokeSchedules[i]);
            // Revoke the rest
            _revokeSchedule(beneficiaries[i], revokeSchedules[i]);
        }
    }

    function revokeAllSchedules(address[] calldata beneficiaries) external {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            // Transfer any unclaimed funds
            _transferPerSchedule(beneficiaries[i]);
            // Revoke the rest
            _revokeAllSchedules(beneficiaries[i]);
        }
    }

    function _revokeAllSchedules(address beneficiary) internal {
        require(beneficiary != address(0), "Invalid address");

        for (uint256 i = 0; i < scheduleNames[beneficiary].length; i++) {
            _revokeSchedule(beneficiary, scheduleNames[beneficiary][i]);
        }
    }

    function _revokeSchedule(address beneficiary, bytes32 scheduleName)
        internal
    {
        address token = schedules[beneficiary][scheduleName].token;

        require(_isTokenAdmin(token, msg.sender));

        schedules[beneficiary][scheduleName].revoked = true;
        schedules[beneficiary][scheduleName].revokedAt = block.timestamp;
        schedules[beneficiary][scheduleName].revokedBy = msg.sender;

        uint256 redeemAmount = schedules[beneficiary][scheduleName]
            .vestingAmount
            .sub(schedules[beneficiary][scheduleName].claimedAmount);

        // Burn tokens
        IERC1410(token).redeemByPartition(
            schedules[beneficiary][scheduleName].name,
            redeemAmount,
            ""
        );

        emit ScheduleRevoked(token, beneficiary, scheduleName);
    }

    function claimableAmount(bytes32 scheduleName, address beneficiary)
        external
        view
        returns (uint256)
    {
        return _claimableAmount(scheduleName, beneficiary);
    }

    function vestedAmount(bytes32 scheduleName, address beneficiary)
        external
        view
        returns (uint256)
    {
        return _vestedAmount(scheduleName, beneficiary);
    }

    function totalVesting(address token, address beneficiary)
        external
        view
        returns (uint256)
    {
        uint256 _totalVesting = 0;
        for (
            uint256 i = 0;
            i < scheduleNamesPerToken[beneficiary][token].length;
            i++
        ) {
            _totalVesting = _totalVesting.add(
                schedules[beneficiary][
                    scheduleNamesPerToken[beneficiary][token][i]
                ].vestingAmount
            );
        }

        return _totalVesting;
    }

    function totalVested(address token, address beneficiary)
        external
        view
        returns (uint256)
    {
        uint256 _totalVested = 0;
        for (
            uint256 i = 0;
            i < scheduleNamesPerToken[beneficiary][token].length;
            i++
        ) {
            _totalVested = _totalVested.add(
                _vestedAmount(
                    scheduleNamesPerToken[beneficiary][token][i],
                    beneficiary
                )
            );
        }

        return _totalVested;
    }

    function totalClaimed(address token, address beneficiary)
        external
        view
        returns (uint256)
    {
        uint256 _totalClaimed = 0;
        for (
            uint256 i = 0;
            i < scheduleNamesPerToken[beneficiary][token].length;
            i++
        ) {
            _totalClaimed = _totalClaimed.add(
                schedules[beneficiary][
                    scheduleNamesPerToken[beneficiary][token][i]
                ].claimedAmount
            );
        }

        return _totalClaimed;
    }

    function _addBeneficiary(address _token, address _beneficiary) internal {
        _beneficiariesByToken[_token].add(_beneficiary);
    }

    function _removeBeneficiary(address _token, address _beneficiary) internal {
        _beneficiariesByToken[_token].remove(_beneficiary);
    }

    function _claimableAmount(bytes32 scheduleName, address beneficiary)
        internal
        view
        returns (uint256)
    {
        uint256 vested = _vestedAmount(scheduleName, beneficiary);
        if (vested == 0) {
            return vested;
        }

        Schedule memory schedule = schedules[beneficiary][scheduleName];

        return vested.sub(schedule.claimedAmount);
    }

    function _vestedAmount(bytes32 scheduleName, address beneficiary)
        internal
        view
        returns (uint256)
    {
        Schedule memory schedule = schedules[beneficiary][scheduleName];

        if (schedule.revoked) {
            return schedule.claimedAmount;
        }

        if (
            block.timestamp < schedule.start || block.timestamp < schedule.cliff
        ) {
            return 0;
        }

        if (
            block.timestamp >= schedule.end ||
            schedule.vestingAmount == schedule.claimedAmount
        ) {
            return schedule.vestingAmount;
        }

        return
            schedule.vestingAmount.mul(block.timestamp.sub(schedule.start)).div(
                schedule.end.sub(schedule.start)
            );
    }

    function _transferPerSchedule(address beneficiary) internal {
        for (uint256 i = 0; i < scheduleNames[beneficiary].length; i++) {
            _transfer(beneficiary, scheduleNames[beneficiary][i]);
        }
    }

    function _transfer(address beneficiary, bytes32 scheduleName) internal {
        uint256 amount = _claimableAmount(scheduleName, beneficiary);

        if (amount > 0) {
            address tokenAddress = schedules[beneficiary][scheduleName].token;
            schedules[beneficiary][scheduleName].claimedAmount = schedules[
                beneficiary
            ][scheduleName].claimedAmount.add(amount);

            IERC1410(tokenAddress).transferByPartition(
                schedules[beneficiary][scheduleName].name,
                beneficiary,
                amount,
                // Switch to keccak256("vested") partition
                abi.encodePacked(
                    bytes32(
                        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                    ),
                    bytes32("vested")
                )
            );

            emit Claimed(tokenAddress, beneficiary, amount);
        }
    }

    function _isTokenAdmin(address securityToken, address operator)
        internal
        view
        returns (bool)
    {
        return AccessControl(securityToken).hasRole(TOKEN_ADMIN_ROLE, operator);
    }

    function _getSchedule(address beneficiary, bytes32 scheduleName)
        private
        view
        returns (Schedule storage)
    {
        require(beneficiary != address(0), "Invalid address");
        require(schedules[beneficiary][scheduleName].exists == true);

        return schedules[beneficiary][scheduleName];
    }
}

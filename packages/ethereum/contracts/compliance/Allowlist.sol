// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Roles.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

abstract contract Allowlist is AccessControl, Roles {
    using EnumerableSet for EnumerableSet.AddressSet;

    event AddedToAllowlist(address indexed account);
    event AddedToBlocklist(address indexed account);

    event RemovedFromAllowlist(address indexed account);
    event RemovedFromBlocklist(address indexed account);

    // keccak256("ALLOWLIST_ADMIN_ROLE")
    bytes32 public constant ALLOWLIST_ADMIN_ROLE =
        0xe9ea3f660aa5a8eccd1bf9d16e6cdf3c1cf9a2b284b830f15bda4493942cb68f;

    // keccak256("BLOCKLIST_ADMIN_ROLE")
    bytes32 public constant BLOCKLIST_ADMIN_ROLE =
        0x167d8d68b016f9cc1b8fb15b910e43cbad3223c8d98cf24f4b170dbd14933df1;

    // Allowlist:
    // - can be used to validate transfer to or from address
    EnumerableSet.AddressSet private _allowlist;
    // TODO: [allowlist] granular transfer restrictions
    // mapping(address => EnumerableSet.AddressSet) private _allowedByToken;
    // mapping(bytes32 => EnumerableSet.AddressSet) private _allowedByPartition;
    // mapping(address => mapping(bytes32 => EnumerableSet.AddressSet)) private _allowedByTokenPartition;

    // Blocklist:
    // - blocks an address from being added to the whitelist until explicitly removed
    // - can be used to validate transfer to or from address
    EnumerableSet.AddressSet private _blocklist;
    // TODO: [blocklist] granular transfer restrictions
    // mapping(address => EnumerableSet.AddressSet) private _blockedByToken;
    // mapping(bytes32 => EnumerableSet.AddressSet) private _blockedByPartition;
    // mapping(address => mapping(bytes32 => EnumerableSet.AddressSet)) private _blockedByTokenPartition;

    modifier onlyAllowlistAdmin {
        require(
            hasRole(ALLOWLIST_ADMIN_ROLE, _msgSender()) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "not admin"
        );
        _;
    }

    modifier onlyBlocklistAdmin {
        require(
            hasRole(BLOCKLIST_ADMIN_ROLE, _msgSender()) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "not admin"
        );
        _;
    }

    function isAllowlisted(address account) public view returns (bool) {
        return _allowlist.contains(account);
    }

    function addToAllowlist(address account) public onlyAllowlistAdmin {
        require(!_blocklist.contains(account), "blocklisted address");

        _allowlist.add(account);

        emit AddedToAllowlist(account);
    }

    function removeFromAllowlist(address account) public onlyAllowlistAdmin {
        if (_allowlist.contains(account)) {
            _allowlist.remove(account);

            emit RemovedFromAllowlist(account);
        }
    }

    function isBlocklisted(address account) public view returns (bool) {
        return _blocklist.contains(account);
    }

    function addToBlocklist(address account) public onlyBlocklistAdmin {
        _blocklist.add(account);

        if (_allowlist.contains(account)) {
            removeFromAllowlist(account);
        }

        emit AddedToBlocklist(account);
    }

    function removeFromBlocklist(address account) public onlyBlocklistAdmin {
        _blocklist.remove(account);

        emit RemovedFromBlocklist(account);
    }

    function allowedAddress(uint256 index) public view returns (address) {
        return _allowlist.at(index);
    }

    function blockedAddress(uint256 index) public view returns (address) {
        return _blocklist.at(index);
    }
}

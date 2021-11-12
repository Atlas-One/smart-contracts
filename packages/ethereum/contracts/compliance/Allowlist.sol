// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Roles.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

abstract contract Allowlist is AccessControlUpgradeable, Roles {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    // keccak256("ALLOWLIST_ADMIN_ROLE")
    bytes32 public constant ALLOWLIST_ADMIN_ROLE =
        0xe9ea3f660aa5a8eccd1bf9d16e6cdf3c1cf9a2b284b830f15bda4493942cb68f;

    // keccak256("BLOCKLIST_ADMIN_ROLE")
    bytes32 public constant BLOCKLIST_ADMIN_ROLE =
        0x167d8d68b016f9cc1b8fb15b910e43cbad3223c8d98cf24f4b170dbd14933df1;

    // Whitelist address has been allowed to hold securities
    EnumerableSetUpgradeable.AddressSet private _whitelist;

    // Blacklist blocks an address from being added to the whitelist until explicitly removed
    EnumerableSetUpgradeable.AddressSet private _blacklist;

    // Address is allowed to hold securities in the tokenAllowlists
    mapping(address => bytes32[]) public accountAllowlists;

    // Token restricts allowed addresses to have the stated lists e.g. keccak256("ON & Accredited") or keccak256("ON & Using Friends And Family Exemption")
    mapping(address => bytes32[]) public tokenAllowlists;

    modifier onlyAllowlistAdmin() {
        require(
            hasRole(ALLOWLIST_ADMIN_ROLE, _msgSender()) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "not admin"
        );
        _;
    }

    modifier onlyBlocklistAdmin() {
        require(
            hasRole(BLOCKLIST_ADMIN_ROLE, _msgSender()) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "not admin"
        );
        _;
    }

    function isAllowed(address account, address token)
        public
        view
        returns (bool)
    {
        require(_whitelist.contains(account));

        if (tokenAllowlists[token].length > 0) {
            for (uint256 i = 0; i < tokenAllowlists[token].length; i++) {
                for (
                    uint256 j = 0;
                    j < accountAllowlists[account].length;
                    j++
                ) {
                    if (
                        tokenAllowlists[token][i] ==
                        accountAllowlists[account][j]
                    ) {
                        return true;
                    }
                }
            }
        }
        return true;
    }

    function isBlocked(address account) public view returns (bool) {
        return _blacklist.contains(account);
    }

    function addToWhitelist(address account) public onlyAllowlistAdmin {
        require(!_blacklist.contains(account), "blocked address");

        _whitelist.add(account);
    }

    function removeFromWhitelist(address account) public onlyAllowlistAdmin {
        if (_whitelist.contains(account)) {
            _whitelist.remove(account);
        }
    }

    function setAccountAllowlists(address account, bytes32[] memory lists)
        public
        onlyAllowlistAdmin
    {
        require(!_blacklist.contains(account), "blocked address");

        _whitelist.add(account);
        accountAllowlists[account] = lists;
    }

    function addToBlacklist(address account) public onlyBlocklistAdmin {
        _blacklist.add(account);

        if (_whitelist.contains(account)) {
            removeFromWhitelist(account);
        }
    }

    function removeFromBlacklist(address account) public onlyBlocklistAdmin {
        _blacklist.remove(account);
    }

    function allowedAddressAtIndex(uint256 index)
        public
        view
        returns (address account, bytes32[] memory lists)
    {
        account = _whitelist.at(index);
        lists = accountAllowlists[account];
    }

    function blockedAddressAtIndex(uint256 index)
        public
        view
        returns (address)
    {
        return _blacklist.at(index);
    }

    function addressAllowlists(address account)
        public
        view
        returns (bytes32[] memory)
    {
        return accountAllowlists[account];
    }

    function setTokenAllowlists(address token, bytes32[] memory lists)
        public
        onlyAllowlistAdmin
    {
        tokenAllowlists[token] = lists;
    }

    uint256[50] private __gap;
}

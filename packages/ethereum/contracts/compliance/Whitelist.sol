// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AdministrableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract Whitelist is Initializable, AdministrableUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    // keccak256("WHITELIST_ADMIN_ROLE")
    bytes32 public constant WHITELIST_ADMIN_ROLE =
        0xe9ea3f660aa5a8eccd1bf9d16e6cdf3c1cf9a2b284b830f15bda4493942cb68f;

    // keccak256("BLACKLIST_ADMIN_ROLE")
    bytes32 public constant BLACKLIST_ADMIN_ROLE =
        0x167d8d68b016f9cc1b8fb15b910e43cbad3223c8d98cf24f4b170dbd14933df1;

    // Whitelist address has been allowed to hold securities
    EnumerableSetUpgradeable.AddressSet private _whitelist;

    // Blacklist blocks an address from being added to the whitelist until explicitly removed
    EnumerableSetUpgradeable.AddressSet private _blacklist;

    modifier onlyWhitelistAdmin() {
        require(
            hasRole(WHITELIST_ADMIN_ROLE, _msgSender()) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "not admin"
        );
        _;
    }

    modifier onlyBlacklistAdmin() {
        require(
            hasRole(BLACKLIST_ADMIN_ROLE, _msgSender()) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "not admin"
        );
        _;
    }

    function initialize() public virtual initializer {
        __AccessControl_init();
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelist.contains(account);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist.contains(account);
    }

    function addToWhitelist(address account) public onlyWhitelistAdmin {
        require(!_blacklist.contains(account), "blacklisted address");

        _whitelist.add(account);
    }

    function removeFromWhitelist(address account) public onlyWhitelistAdmin {
        if (_whitelist.contains(account)) {
            _whitelist.remove(account);
        }
    }

    function addToBlacklist(address account) public onlyBlacklistAdmin {
        _blacklist.add(account);

        if (_whitelist.contains(account)) {
            removeFromWhitelist(account);
        }
    }

    function removeFromBlacklist(address account) public onlyBlacklistAdmin {
        _blacklist.remove(account);
    }

    function whitelistAddressAtIndex(uint256 index)
        public
        view
        returns (address account)
    {
        return _whitelist.at(index);
    }

    function blacklistAddressAtIndex(uint256 index)
        public
        view
        returns (address)
    {
        return _blacklist.at(index);
    }

    uint256[50] private __gap;
}

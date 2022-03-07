// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AdministrableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract WhitelistUpgradeable is Initializable, AdministrableUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    // keccak256("WHITELIST_ADMIN_ROLE")
    bytes32 public constant WHITELIST_ADMIN_ROLE =
        0xe9ea3f660aa5a8eccd1bf9d16e6cdf3c1cf9a2b284b830f15bda4493942cb68f;

    // keccak256("BLACKLIST_ADMIN_ROLE")
    bytes32 public constant BLACKLIST_ADMIN_ROLE =
        0x167d8d68b016f9cc1b8fb15b910e43cbad3223c8d98cf24f4b170dbd14933df1;

    mapping(address => EnumerableSetUpgradeable.AddressSet)
        private _tokenWhitelist;

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

    function isWhitelisted(address token, address account)
        public
        view
        returns (bool)
    {
        return _tokenWhitelist[token].contains(account);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist.contains(account);
    }

    function addToWhitelist(address token, address account)
        public
        onlyWhitelistAdmin
    {
        require(!_blacklist.contains(account), "blacklisted address");

        _tokenWhitelist[token].add(account);
    }

    function removeFromWhitelist(address token, address account)
        public
        onlyWhitelistAdmin
    {
        if (_tokenWhitelist[token].contains(account)) {
            _tokenWhitelist[token].remove(account);
        }
    }

    function addToBlacklist(address account) public onlyBlacklistAdmin {
        _blacklist.add(account);
    }

    function removeFromBlacklist(address account) public onlyBlacklistAdmin {
        _blacklist.remove(account);
    }

    function whitelistAddressAtIndex(address token, uint256 index)
        public
        view
        returns (address account)
    {
        return _tokenWhitelist[token].at(index);
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

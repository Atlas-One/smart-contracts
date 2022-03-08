// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC1400.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract ERC1400Allowable is ERC1400 {
    using EnumerableSet for EnumerableSet.AddressSet;

    // keccak256("WHITELIST_ADMIN_ROLE")
    bytes32 public constant WHITELIST_ADMIN_ROLE =
        0xe9ea3f660aa5a8eccd1bf9d16e6cdf3c1cf9a2b284b830f15bda4493942cb68f;

    // keccak256("BLACKLIST_ADMIN_ROLE")
    bytes32 public constant BLACKLIST_ADMIN_ROLE =
        0x167d8d68b016f9cc1b8fb15b910e43cbad3223c8d98cf24f4b170dbd14933df1;

    EnumerableSet.AddressSet private _whitelist;
    EnumerableSet.AddressSet private _blacklist;

    constructor(
        address[] memory whitelistAdmins,
        address[] memory blacklistAdmins
    ) {
        for (uint256 i = 0; i < whitelistAdmins.length; i++) {
            _setupRole(WHITELIST_ADMIN_ROLE, whitelistAdmins[i]);
        }
        for (uint256 i = 0; i < blacklistAdmins.length; i++) {
            _setupRole(BLACKLIST_ADMIN_ROLE, blacklistAdmins[i]);
        }
    }

    function addToWhitelist(address account) public {
        _onlyWhitelistAdmin();
        require(!_blacklist.contains(account), "blacklisted");
        _whitelist.add(account);
    }

    function addToBlacklist(address account) public {
        _onlyBlacklistAdmin();
        _blacklist.add(account);
        _whitelist.remove(account);
    }

    function removeFromWhitelist(address account) public {
        _whitelist.remove(account);
    }

    function removeFromBlacklist(address account) public {
        _blacklist.remove(account);
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelist.contains(account);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _whitelist.contains(account);
    }

    function _onlyWhitelistAdmin() internal view {
        require(
            hasRole(WHITELIST_ADMIN_ROLE, _msgSender()) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "58"
        );
    }

    function _onlyBlacklistAdmin() internal view {
        require(
            hasRole(BLACKLIST_ADMIN_ROLE, _msgSender()) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "58"
        );
    }

    // reduce contract size
    // function _canTransferByPartition(
    //     bytes32 partition,
    //     address operator,
    //     address from,
    //     address to,
    //     uint256 value,
    //     bytes memory data
    // )
    //     internal
    //     view
    //     virtual
    //     override
    //     returns (bytes1 statusCode, bytes32 appCode)
    // {
    //     if (_isController(_msgSender()) || (isAllowed(from) && isAllowed(to))) {
    //         return (bytes1(0x58), bytes32(0));
    //     }

    //     return
    //         super._canTransferByPartition(
    //             partition,
    //             operator,
    //             from,
    //             to,
    //             value,
    //             data
    //         );
    // }

    function _beforeTokenTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal virtual override {
        require(
            (_isController(_msgSender()) ||
                isWhitelisted(from) ||
                from == address(0)) && (isWhitelisted(to) || to == address(0)),
            "58"
        );

        super._beforeTokenTransfer(
            partition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );
    }
}

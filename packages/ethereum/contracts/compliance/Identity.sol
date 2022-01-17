// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./AdministrableUpgradeable.sol";

contract Identity is Initializable, AdministrableUpgradeable {
    mapping(bytes32 => bool) public identities;

    mapping(address => bytes32) public accountIdentity;
    mapping(bytes32 => mapping(address => bool)) public identityAccounts;

    mapping(bytes32 => mapping(bytes32 => bool)) public identityClaims;

    function initialize() public virtual initializer {
        __AccessControl_init();
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function addIdentity(bytes32 id) public {
        identities[id] = true;
    }

    function addClaim(bytes32 id, bytes32 claim) public {
        identityClaims[id][claim] = true;
    }

    function removeClaim(bytes32 id, bytes32 claim) public {
        identityClaims[id][claim] = false;
    }

    function addAccount(bytes32 id, address account) public {
        require(accountIdentity[account] == bytes32(0));

        identityAccounts[id][account] = true;
    }

    function removeAccount(bytes32 id, address account) public {
        require(accountIdentity[account] == id);

        identityAccounts[id][account] = false;
    }

    function ownsAccount(bytes32 id, address account)
        public
        view
        returns (bool)
    {
        return identityAccounts[id][account];
    }

    function claimIsValid(bytes32 id, bytes32 claim)
        public
        view
        returns (bool)
    {
        return identityClaims[id][claim];
    }
}

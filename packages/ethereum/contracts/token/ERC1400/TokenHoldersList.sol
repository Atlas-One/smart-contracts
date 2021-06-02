// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC1400.sol";

abstract contract TokenHoldersList is ERC1400 {
    address[] public tokenHolders;
    mapping(address => uint256) internal _tokenHoldersIndex;

    function tokenHoldersCount() public view returns (uint256) {
        return tokenHolders.length;
    }

    function allTokenHolders() public view returns (address[] memory) {
        return tokenHolders;
    }

    function _addTokenHolder(address _tokenHolder) internal {
        if (_tokenHoldersIndex[_tokenHolder] == 0) {
            tokenHolders.push(_tokenHolder);
            _tokenHoldersIndex[_tokenHolder] = tokenHolders.length;
        }
    }

    function _removeTokenHolder(address _tokenHolder) internal {
        if (tokenHolders.length > 0 && _balances[_tokenHolder] == 0) {
            uint256 removeIndex = _tokenHoldersIndex[_tokenHolder] - 1;
            uint256 lastIndex = tokenHolders.length - 1;

            if (tokenHolders.length >= 2) {
                tokenHolders[removeIndex] = tokenHolders[lastIndex];
                _tokenHoldersIndex[tokenHolders[lastIndex]] = removeIndex;
            }

            delete tokenHolders[lastIndex];
            delete _tokenHoldersIndex[_tokenHolder];
        }
    }

    function _afterTokenTransfer(
        bytes32, /* partition */
        address, /* operator */
        address from,
        address to,
        uint256, /* value */
        bytes memory, /* data */
        bytes memory /* operatorData */
    ) internal virtual override {
        if (to == address(0)) {
            // handle burning
            _removeTokenHolder(from);
        } else if (to == address(0)) {
            // hanlde minting
            _addTokenHolder(to);
        } else {
            // handle transfer
            _removeTokenHolder(from);
            _addTokenHolder(to);
        }
    }
}

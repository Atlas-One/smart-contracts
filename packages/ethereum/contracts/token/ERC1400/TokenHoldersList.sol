// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC1400.sol";

abstract contract TokenHoldersList is ERC1400 {
    address[] internal _tokenHolders;
    mapping(address => uint256) internal _tokenHoldersIndex;

    function tokenHolders() public view returns (address[] memory) {
        return _tokenHolders;
    }

    function _addTokenHolder(address _tokenHolder) internal {
        if (_tokenHoldersIndex[_tokenHolder] == 0) {
            _tokenHolders.push(_tokenHolder);
            _tokenHoldersIndex[_tokenHolder] = _tokenHolders.length;
        }
    }

    function _removeTokenHolder(address _tokenHolder) internal {
        if (_tokenHolders.length > 0 && _balances[_tokenHolder] == 0) {
            uint256 removeIndex = _tokenHoldersIndex[_tokenHolder] - 1;
            uint256 lastIndex = _tokenHolders.length - 1;

            if (_tokenHolders.length >= 2) {
                _tokenHolders[removeIndex] = _tokenHolders[lastIndex];
                _tokenHoldersIndex[_tokenHolders[lastIndex]] = removeIndex;
            }

            delete _tokenHolders[lastIndex];
            delete _tokenHoldersIndex[_tokenHolder];
        }
    }

    function _afterTokenTransfer(
        bytes32, /* partition */
        address, /*operator */
        address from,
        address to,
        uint256, /*value */
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

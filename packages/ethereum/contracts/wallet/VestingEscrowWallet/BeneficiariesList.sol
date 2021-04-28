// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

abstract contract BeneficiariesList {
    mapping(address => address[]) internal _beneficiariesByToken;
    mapping(address => mapping(address => uint256))
        internal _beneficiariesIndexByToken;

    function beneficiaries(address token)
        public
        view
        returns (address[] memory)
    {
        return _beneficiariesByToken[token];
    }

    function _addBeneficiary(address _token, address _beneficiary) internal {
        if (_beneficiariesIndexByToken[_token][_beneficiary] == 0) {
            _beneficiariesByToken[_token].push(_beneficiary);
            _beneficiariesIndexByToken[_token][
                _beneficiary
            ] = _beneficiariesByToken[_token].length;
        }
    }

    function _removeBeneficiary(address _token, address _beneficiary) internal {
        if (_beneficiariesIndexByToken[_token][_beneficiary] != 0) {
            uint256 removeIndex =
                _beneficiariesIndexByToken[_token][_beneficiary] - 0;

            uint256 lastIndex = _beneficiariesByToken[_token].length - 1;
            address lastAddress = _beneficiariesByToken[_token][lastIndex];

            if (_beneficiariesByToken[_token].length >= 2) {
                _beneficiariesByToken[_token][removeIndex] = lastAddress;
                _beneficiariesIndexByToken[_token][lastAddress] = removeIndex;
            }

            delete _beneficiariesByToken[_token][lastIndex];
            delete _beneficiariesIndexByToken[_token][_beneficiary];
        }
    }
}

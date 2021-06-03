// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

abstract contract BeneficiariesList {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) internal _beneficiariesByToken;

    function beneficiary(address token, uint256 index)
        public
        view
        returns (address)
    {
        return _beneficiariesByToken[token].at(index);
    }

    function _addBeneficiary(address _token, address _beneficiary) internal {
        _beneficiariesByToken[_token].add(_beneficiary);
    }

    function _removeBeneficiary(address _token, address _beneficiary) internal {
        _beneficiariesByToken[_token].remove(_beneficiary);
    }
}

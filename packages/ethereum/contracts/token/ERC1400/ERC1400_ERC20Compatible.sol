// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC1400.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC1400_ERC20Compatible is IERC20, ERC1400 {
    using SafeMath for uint256;

    mapping(address => mapping(address => uint256)) internal _allowances;

    constructor(
        string memory name,
        string memory symbol,
        uint256 granularity,
        bytes32[] memory defaultPartitions,
        address[] memory controllers,
        address[] memory validators
    )
        public
        ERC1400(
            name,
            symbol,
            granularity,
            defaultPartitions,
            controllers,
            validators
        )
    {}

    /**
     * @dev Get the total number of issued tokens.
     * @return Total supply of tokens currently in circulation.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Get the balance of the account with address 'tokenHolder'.
     * @param tokenHolder Address for which the balance is returned.
     * @return Amount of token held by 'tokenHolder' in the token contract.
     */
    function balanceOf(address tokenHolder)
        external
        view
        override
        returns (uint256)
    {
        return _balances[tokenHolder];
    }

    /**
     * @dev Transfer token for a specified address.
     * @param to The address to transfer to.
     * @param value The value to be transferred.
     * @return A boolean that indicates if the operation was successful.
     */
    function transfer(address to, uint256 value)
        external
        override
        returns (bool)
    {
        _transferByDefaultPartitions(msg.sender, msg.sender, to, value, "");
        return true;
    }

    /**
     * @dev Check the value of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the value of tokens still available for the spender.
     */
    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of 'msg.sender'.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean that indicates if the operation was successful.
     */
    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        require(spender != address(0), "56"); // 0x56	invalid sender
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address which you want to transfer tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(
            _isOperator(msg.sender, from) ||
                (value <= _allowances[from][msg.sender]),
            "53"
        ); // 0x53	insufficient allowance

        if (_allowances[from][msg.sender] >= value) {
            _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(
                value
            );
        } else {
            _allowances[from][msg.sender] = 0;
        }

        _transferByDefaultPartitions(msg.sender, from, to, value, "");
        return true;
    }

    function _afterTokenTransfer(
        bytes32, /* partition */
        address, /* operator */
        address from,
        address to,
        uint256 value,
        bytes memory, /* data */
        bytes memory /* operatorData */
    ) internal virtual override {
        if (to == address(0)) {
            emit Transfer(from, to, value);
        } else if (from == address(0)) {
            emit Transfer(from, to, value);
        } else {
            emit Transfer(from, to, value);
        }
    }
}

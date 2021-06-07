// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ERC1400_ERC20Compatible.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";

import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";

contract ERC1400_ERC777Compatible is ERC1400_ERC20Compatible {
    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    event Minted(
        address indexed operator,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    event Burned(
        address indexed operator,
        address indexed from,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    IERC1820Registry internal constant _ERC1820_REGISTRY =
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    // We inline the result of the following hashes because Solidity doesn't resolve them at compile time.
    // See https://github.com/ethereum/solidity/issues/4024.

    // keccak256("ERC1400Token")
    bytes32 internal constant _ERC1400_INTERFACE_NAME =
        0xf9924936296af2a5ccae1dd57fa11f492d390f57f49220c78a81bed0241f0d1c;

    // keccak256("ERC777Token")
    bytes32 internal constant _ERC777_INTERFACE_NAME =
        0xac7fbab5f54a3ca8194167523c6753bfeb96a445279294b6125b68cce2177054;

    // keccak256("ERC20Token")
    bytes32 internal constant _ERC20_INTERFACE_NAME =
        0xaea199e31a596269b42cdafd93407f14436db6e4cad65417994c2eb37381e05a;

    // keccak256("ERC777TokensSender")
    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH =
        0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895;

    // keccak256("ERC777TokensRecipient")
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH =
        0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b;

    constructor(
        string memory name,
        string memory symbol,
        uint256 granularity,
        bytes32[] memory defaultPartitions,
        address[] memory admins,
        address[] memory controllers,
        address[] memory validators,
        address[] memory burners,
        address[] memory minters,
        address[] memory pausers
    )
        public
        ERC1400_ERC20Compatible(
            name,
            symbol,
            granularity,
            defaultPartitions,
            admins,
            controllers,
            validators,
            burners,
            minters,
            pausers
        )
    {
        // register interfaces
        _ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            _ERC1400_INTERFACE_NAME,
            address(this)
        );
        _ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            _ERC777_INTERFACE_NAME,
            address(this)
        );
        _ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            _ERC20_INTERFACE_NAME,
            address(this)
        );
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * If send or receive hooks are registered for the caller and `recipient`,
     * the corresponding functions will be called with `data` and empty
     * `operatorData`. See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits a {Sent} event.
     *
     * Requirements
     *
     * - the caller must have at least `amount` tokens.
     * - `recipient` cannot be the zero address.
     * - if `recipient` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    //  reduce contract size
    // function send(
    //     address recipient,
    //     uint256 amount,
    //     bytes calldata data
    // ) external {
    //     _transferByDefaultPartitions(
    //         msg.sender,
    //         msg.sender,
    //         recipient,
    //         amount,
    //         data
    //     );
    // }

    /**
     * @dev Destroys `amount` tokens from the caller's account, reducing the
     * total supply.
     *
     * If a send hook is registered for the caller, the corresponding function
     * will be called with `data` and empty `operatorData`. See {IERC777Sender}.
     *
     * Emits a {Burned} event.
     *
     * Requirements
     *
     * - the caller must have at least `amount` tokens.
     */
    //  reduce contract size
    // function burn(uint256 amount, bytes calldata data) external {
    //     _redeemByDefaultPartitions(msg.sender, msg.sender, amount, data);
    // }

    /**
     * @dev Returns true if an account is an operator of `tokenHolder`.
     * Operators can send and burn tokens on behalf of their owners. All
     * accounts are their own operator.
     *
     * See {operatorSend} and {operatorBurn}.
     */
    //  reduce contract size
    // function isOperatorFor(address operator, address tokenHolder)
    //     external
    //     view
    //     returns (bool)
    // {
    //     return _isOperator(operator, tokenHolder);
    // }

    /**
     * @dev Returns the list of default operators. These accounts are operators
     * for all token holders, even if {authorizeOperator} was never called on
     * them.
     *
     * This list is immutable, but individual holders may revoke these via
     * {revokeOperator}, in which case {isOperatorFor} will return false.
     */
    //  reduce contract size
    // function defaultOperators() external pure returns (address[] memory) {
    //     address[] memory _defaultOperators;
    //     return _defaultOperators;
    // }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient`. The caller must
     * be an operator of `sender`.
     *
     * If send or receive hooks are registered for `sender` and `recipient`,
     * the corresponding functions will be called with `data` and
     * `operatorData`. See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits a {Sent} event.
     *
     * Requirements
     *
     * - `sender` cannot be the zero address.
     * - `sender` must have at least `amount` tokens.
     * - the caller must be an operator for `sender`.
     * - `recipient` cannot be the zero address.
     * - if `recipient` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    // function operatorSend(
    //     address sender,
    //     address recipient,
    //     uint256 amount,
    //     bytes calldata data,
    //     bytes calldata /* operatorData */
    // ) external {
    //     _transferByDefaultPartitions(
    //         msg.sender,
    //         sender,
    //         recipient,
    //         amount,
    //         data
    //     );
    // }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the total supply.
     * The caller must be an operator of `account`.
     *
     * If a send hook is registered for `account`, the corresponding function
     * will be called with `data` and `operatorData`. See {IERC777Sender}.
     *
     * Emits a {Burned} event.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     * - the caller must be an operator for `account`.
     */
    // function operatorBurn(
    //     address account,
    //     uint256 amount,
    //     bytes calldata data,
    //     bytes calldata /* operatorData */
    // ) external {
    //     require(_isOperator(msg.sender, account), "58"); // 0x58	invalid operator (transfer agent)

    //     _redeemByDefaultPartitions(msg.sender, account, amount, data);
    // }

    /**
     * @dev Call from.tokensToSend() if the interface is registered
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     */
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        address implementer =
            _ERC1820_REGISTRY.getInterfaceImplementer(
                from,
                _TOKENS_SENDER_INTERFACE_HASH
            );
        if (implementer != address(0)) {
            IERC777Sender(implementer).tokensToSend(
                operator,
                from,
                to,
                amount,
                userData,
                operatorData
            );
        }
    }

    /**
     * @dev Call to.tokensReceived() if the interface is registered. Reverts if the recipient is a contract but
     * tokensReceived() was not registered for the recipient
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) private {
        address implementer =
            _ERC1820_REGISTRY.getInterfaceImplementer(
                to,
                _TOKENS_RECIPIENT_INTERFACE_HASH
            );
        if (implementer != address(0)) {
            IERC777Recipient(implementer).tokensReceived(
                operator,
                from,
                to,
                amount,
                userData,
                operatorData
            );
        } else if (requireReceptionAck) {
            require(!to.isContract());
        }
    }

    function _beforeTokenTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal virtual override {
        super._beforeTokenTransfer(
            partition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );

        _callTokensToSend(from, from, to, value, "", "");
    }

    function _afterTokenTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal virtual override {
        super._afterTokenTransfer(
            partition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );

        if (to == address(0)) {
            _callTokensReceived(operator, from, to, value, "", "", false);

            emit Minted(operator, to, value, data, operatorData);
        } else if (from == address(0)) {
            emit Burned(operator, from, value, data, operatorData);
        } else {
            _callTokensReceived(operator, from, to, value, "", "", false);

            emit Sent(operator, from, to, value, data, operatorData);
        }
    }
}

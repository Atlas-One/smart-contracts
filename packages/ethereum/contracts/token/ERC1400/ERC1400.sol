// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../interface/IERC1644.sol";
import "../../interface/IERC1410.sol";
import "../../interface/IERC1594.sol";
import "../../interface/IERC1643.sol";

import "./ExtendedValidation.sol";
import "./PartitionDestination.sol";

import "../../compliance/ERC1400Administrable.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC1400 is
    IERC1644,
    IERC1410,
    IERC1594,
    IERC1643,
    ERC1400Administrable,
    ExtendedValidation,
    PartitionDestination
{
    using SafeMath for uint256;

    string internal _name;
    string internal _symbol;
    uint256 internal _granularity;
    uint8 internal _decimals;

    uint256 internal _totalSupply;

    bool internal _isControllable;

    bool internal _isIssuable;

    mapping(address => uint256) internal _balances;

    struct Document {
        string documentURI;
        bytes32 documentHash;
    }

    // Mapping for token URIs.
    mapping(bytes32 => Document) internal _documents;

    // List of token default partitions
    // Supports:
    // - transferWithData
    // - redeem
    // - for other protocol compatibility where you don't specify transferByPartition e.g. ERC20
    bytes32[] internal _defaultPartitions;

    // List of partitions.
    bytes32[] internal _totalPartitions;

    // Mapping from partition to their index.
    mapping(bytes32 => uint256) internal _indexOfTotalPartitions;

    // Mapping from partition to global balance of corresponding partition.
    mapping(bytes32 => uint256) internal _totalSupplyByPartition;

    // Mapping from tokenHolder to their partitions.
    mapping(address => bytes32[]) internal _partitionsOf;

    // Mapping from (tokenHolder, partition) to their index.
    mapping(address => mapping(bytes32 => uint256))
        internal _indexOfPartitionsOf;

    // Mapping from (tokenHolder, partition) to balance of corresponding partition.
    mapping(address => mapping(bytes32 => uint256))
        internal _balanceOfByPartition;

    // Mapping from (operator, tokenHolder) to authorized status. [TOKEN-HOLDER-SPECIFIC]
    mapping(address => mapping(address => bool)) internal _authorizedOperator;

    // Mapping from (partition, tokenHolder, spender) to allowed value. [TOKEN-HOLDER-SPECIFIC]
    mapping(bytes32 => mapping(address => mapping(address => uint256)))
        internal _allowancesByPartition;

    // Mapping from (tokenHolder, partition, operator) to 'approved for partition' status. [TOKEN-HOLDER-SPECIFIC]
    mapping(address => mapping(bytes32 => mapping(address => bool)))
        internal _authorizedOperatorByPartition;

    /**
     * @dev Initialize ERC1400
     * @param name_ Name of the token.
     * @param symbol_ Symbol of the token.
     * @param granularity_ Granularity of the token.
     * @param controllers Controllers
     * @param validators Validator
     * not specified, like the case ERC20 tranfers.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 granularity_,
        uint8 decimals_,
        address[] memory admins,
        address[] memory controllers,
        address[] memory validators,
        address[] memory burners,
        address[] memory minters,
        address[] memory pausers,
        address[] memory partitioners
    ) {
        require(granularity_ >= 1); // Constructor Blocked - Token granularity can not be lower than 1

        _name = name_;
        _symbol = symbol_;
        _totalSupply = 0;

        _granularity = granularity_;
        _decimals = decimals_;

        _defaultPartitions = [bytes32("issued"), bytes32("vested")];

        _isIssuable = true;
        _isControllable = true;

        if (admins.length > 0) {
            // set token admins
            for (uint256 i = 0; i < admins.length; i++) {
                _setupRole(ADMIN_ROLE, admins[i]);
            }
        } else {
            // set token admin
            _setupRole(ADMIN_ROLE, msg.sender);
        }
        // set controllers
        for (uint256 i = 0; i < controllers.length; i++) {
            _setupRole(CONTROLLER_ROLE, controllers[i]);
        }
        // set validators
        for (uint256 i = 0; i < validators.length; i++) {
            _setupRole(VALIDATOR_ROLE, validators[i]);
        }
        // set burners
        for (uint256 i = 0; i < burners.length; i++) {
            _setupRole(BURNER_ROLE, burners[i]);
        }
        // set minters
        for (uint256 i = 0; i < minters.length; i++) {
            _setupRole(MINTER_ROLE, minters[i]);
        }
        // set pausers
        for (uint256 i = 0; i < pausers.length; i++) {
            _setupRole(PAUSER_ROLE, pausers[i]);
        }
        // set partitioners
        for (uint256 i = 0; i < partitioners.length; i++) {
            _setupRole(PARTITIONER_ROLE, partitioners[i]);
        }
    }

    /**
     * @dev Get the name of the token, e.g., "MyToken".
     * @return Name of the token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev Get the symbol of the token, e.g., "MYT".
     * @return Symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Get the smallest part of the token that’s not divisible.
     * @return The smallest non-divisible part of the token.
     */
    function granularity() external view returns (uint256) {
        return _granularity;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Get list of existing partitions.
     * @return Array of all exisiting partitions.
     */
    function totalPartitions() external view returns (bytes32[] memory) {
        return _totalPartitions;
    }

    /**
     * @dev Get the total number of issued tokens for a given partition.
     * @param partition Name of the partition.
     * @return Total supply of tokens currently in circulation, for a given partition.
     */
    function totalSupplyByPartition(bytes32 partition)
        external
        view
        returns (uint256)
    {
        return _totalSupplyByPartition[partition];
    }

    /**
     * @dev Get default partitions to transfer from.
     * Function used for ERC20 retrocompatibility.
     * For example, a security token may return the bytes32("unrestricted").
     * @return Array of default partitions.
     */
    function getDefaultPartitions() external view returns (bytes32[] memory) {
        return _defaultPartitions;
    }

    /**
     * @dev Set default partitions to transfer from.
     * Function used for ERC20 retrocompatibility.
     * @param partitions partitions to use by default when not specified.
     */
    function setDefaultPartitions(bytes32[] calldata partitions) external {
        _onlyAdmin(msg.sender);
        _defaultPartitions = partitions;
    }

    function _onlyIssuable() internal view {
        require(_isIssuable, "55"); // 0x55	funds locked (lockup period)
    }

    /**
     * @dev Access a document associated with the token.
     * @param documentName Short name (represented as a bytes32) associated to the document.
     * @return Requested document + document hash.
     */
    function getDocument(bytes32 documentName)
        external
        view
        override
        returns (string memory, bytes32)
    {
        require(bytes(_documents[documentName].documentURI).length != 0); // Action Blocked - Empty document
        return (
            _documents[documentName].documentURI,
            _documents[documentName].documentHash
        );
    }

    /**
     * @dev Associate a document with the token.
     * @param documentName Short name (represented as a bytes32) associated to the document.
     * @param uri Document content.
     * @param documentHash Hash of the document [optional parameter].
     */
    function setDocument(
        bytes32 documentName,
        string calldata uri,
        bytes32 documentHash
    ) external override {
        _onlyController(msg.sender);
        _documents[documentName] = Document({
            documentURI: uri,
            documentHash: documentHash
        });
        emit DocumentUpdated(documentName, uri, documentHash);
    }

    /**
     * @dev Remove document associated with the token.
     * @param documentName Short name (represented as a bytes32) associated to the document.
     */
    function removeDocument(bytes32 documentName) external override {
        _onlyController(msg.sender);
        string memory documentURI = _documents[documentName].documentURI;
        bytes32 documentHash = _documents[documentName].documentHash;

        delete _documents[documentName];

        emit DocumentRemoved(documentName, documentURI, documentHash);
    }

    /**
     * @dev Get balance of a tokenholder for a specific partition.
     * @param partition Name of the partition.
     * @param tokenHolder Address for which the balance is returned.
     * @return Amount of token of partition 'partition' held by 'tokenHolder' in the token contract.
     */
    function balanceOfByPartition(bytes32 partition, address tokenHolder)
        external
        view
        override
        returns (uint256)
    {
        return _balanceOfByPartition[tokenHolder][partition];
    }

    /**
     * @dev Get partitions index of a tokenholder.
     * @param tokenHolder Address for which the partitions index are returned.
     * @return Array of partitions index of 'tokenHolder'.
     */
    function partitionsOf(address tokenHolder)
        external
        view
        override
        returns (bytes32[] memory)
    {
        return _partitionsOf[tokenHolder];
    }

    /**
     * @dev Transfer the amount of tokens from the address 'msg.sender' to the address 'to'.
     * @param to Token recipient.
     * @param value Number of tokens to transfer.
     * @param data Information attached to the transfer, by the token holder.
     */
    function transferWithData(
        address to,
        uint256 value,
        bytes calldata data
    ) external override {
        _transferByDefaultPartitions(msg.sender, msg.sender, to, value, data);
    }

    /**
     * @dev Transfer the amount of tokens on behalf of the address 'from' to the address 'to'.
     * @param from Token holder (or 'address(0)' to set from to 'msg.sender').
     * @param to Token recipient.
     * @param value Number of tokens to transfer.
     * @param data Information attached to the transfer, and intended for the token holder ('from').
     */
    function transferFromWithData(
        address from,
        address to,
        uint256 value,
        bytes calldata data
    ) external override {
        require(_isOperator(msg.sender, from), "58"); // 0x58	invalid operator (transfer agent)

        _transferByDefaultPartitions(msg.sender, from, to, value, data);
    }

    /**
     * @dev Transfer tokens from a specific partition.
     * @param partition Name of the partition.
     * @param to Token recipient.
     * @param value Number of tokens to transfer.
     * @param data Information attached to the transfer, by the token holder.
     * @return Destination partition.
     */
    function transferByPartition(
        bytes32 partition,
        address to,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes32) {
        return
            _transferByPartition(
                partition,
                msg.sender,
                msg.sender,
                to,
                value,
                data,
                ""
            );
    }

    /**
     * @dev Transfer tokens from a specific partition through an operator.
     * @param partition Name of the partition.
     * @param from Token holder.
     * @param to Token recipient.
     * @param value Number of tokens to transfer.
     * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
     * @param operatorData Information attached to the transfer, by the operator.
     * @return Destination partition.
     */
    function operatorTransferByPartition(
        bytes32 partition,
        address from,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata operatorData
    ) external override returns (bytes32) {
        require(
            _isOperatorForPartition(partition, msg.sender, from) ||
                (value <= _allowancesByPartition[partition][from][msg.sender]),
            "53"
        ); // 0x53	insufficient allowance

        if (_allowancesByPartition[partition][from][msg.sender] >= value) {
            _allowancesByPartition[partition][from][
                msg.sender
            ] = _allowancesByPartition[partition][from][msg.sender].sub(value);
        } else {
            _allowancesByPartition[partition][from][msg.sender] = 0;
        }

        return
            _transferByPartition(
                partition,
                msg.sender,
                from,
                to,
                value,
                data,
                operatorData
            );
    }

    /**
     * @notice This function allows an authorised address to transfer tokens between any two token holders.
     * The transfer must still respect the balances of the token holders (so the transfer must be for at most
     * `balanceOf(_from)` tokens) and potentially also need to respect other transfer restrictions.
     * @dev This function can only be executed by the `controller` address.
     * @param _from Address The address which you want to send tokens from
     * @param _to Address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     * @param _data data to validate the transfer. (It is not used in this reference implementation
     * because use of `_data` parameter is implementation specific).
     * @param _operatorData data attached to the transfer by controller to emit in event. (It is more like a reason string
     * for calling this function (aka force transfer) which provides the transparency on-chain).
     */
    function controllerTransfer(
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _data,
        bytes calldata _operatorData
    ) external override {
        _onlyController(msg.sender);
        _transferByDefaultPartitions(_msgSender(), _from, _to, _value, _data);
        emit ControllerTransfer(
            _msgSender(),
            _from,
            _to,
            _value,
            _data,
            _operatorData
        );
    }

    /**
     * @notice This function allows an authorised address to redeem tokens for any token holder.
     * The redemption must still respect the balances of the token holder (so the redemption must be for at most
     * `balanceOf(_tokenHolder)` tokens) and potentially also need to respect other transfer restrictions.
     * @dev This function can only be executed by the `controller` address.
     * @param _tokenHolder The account whose tokens will be redeemed.
     * @param _value uint256 the amount of tokens need to be redeemed.
     * @param _data data to validate the transfer. (It is not used in this reference implementation
     * because use of `_data` parameter is implementation specific).
     * @param _operatorData data attached to the transfer by controller to emit in event. (It is more like a reason string
     * for calling this function (aka force transfer) which provides the transparency on-chain).
     */
    function controllerRedeem(
        address _tokenHolder,
        uint256 _value,
        bytes calldata _data,
        bytes calldata _operatorData
    ) external override {
        _onlyController(msg.sender);
        _redeemByDefaultPartitions(_msgSender(), _tokenHolder, _value, _data);
        emit ControllerRedemption(
            _msgSender(),
            _tokenHolder,
            _value,
            _data,
            _operatorData
        );
    }

    /**
     * @dev Set a third party operator address as an operator of 'msg.sender' to transfer
     * and redeem tokens on its behalf.
     * @param operator Address to set as an operator for 'msg.sender'.
     */
    function authorizeOperator(address operator) external override {
        require(operator != msg.sender);
        _authorizedOperator[operator][msg.sender] = true;
        emit AuthorizedOperator(operator, msg.sender);
    }

    /**
     * @dev Remove the right of the operator address to be an operator for 'msg.sender'
     * and to transfer and redeem tokens on its behalf.
     * @param operator Address to rescind as an operator for 'msg.sender'.
     */
    function revokeOperator(address operator) external override {
        require(operator != msg.sender);
        _authorizedOperator[operator][msg.sender] = false;
        emit RevokedOperator(operator, msg.sender);
    }

    /**
     * @dev Set 'operator' as an operator for 'msg.sender' for a given partition.
     * @param partition Name of the partition.
     * @param operator Address to set as an operator for 'msg.sender'.
     */
    function authorizeOperatorByPartition(bytes32 partition, address operator)
        external
        override
    {
        _authorizedOperatorByPartition[msg.sender][partition][operator] = true;
        emit AuthorizedOperatorByPartition(partition, operator, msg.sender);
    }

    /**
     * @dev Remove the right of the operator address to be an operator on a given
     * partition for 'msg.sender' and to transfer and redeem tokens on its behalf.
     * @param partition Name of the partition.
     * @param operator Address to rescind as an operator on given partition for 'msg.sender'.
     */
    function revokeOperatorByPartition(bytes32 partition, address operator)
        external
        override
    {
        _authorizedOperatorByPartition[msg.sender][partition][operator] = false;
        emit RevokedOperatorByPartition(partition, operator, msg.sender);
    }

    /**
     * @dev Indicate whether the operator address is an operator of the tokenHolder address.
     * @param operator Address which may be an operator of tokenHolder.
     * @param tokenHolder Address of a token holder which may have the operator address as an operator.
     * @return 'true' if operator is an operator of 'tokenHolder' and 'false' otherwise.
     */
    function isOperator(address operator, address tokenHolder)
        external
        view
        override
        returns (bool)
    {
        return _isOperator(operator, tokenHolder);
    }

    /**
     * @dev Indicate whether the operator address is an operator of the tokenHolder
     * address for the given partition.
     * @param partition Name of the partition.
     * @param operator Address which may be an operator of tokenHolder for the given partition.
     * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given partition.
     * @return 'true' if 'operator' is an operator of 'tokenHolder' for partition 'partition' and 'false' otherwise.
     */
    function isOperatorForPartition(
        bytes32 partition,
        address operator,
        address tokenHolder
    ) external view override returns (bool) {
        return _isOperatorForPartition(partition, operator, tokenHolder);
    }

    /**
     * @dev Know if new tokens can be issued in the future.
     * @return bool 'true' if tokens can still be issued by the issuer, 'false' if they can't anymore.
     */
    function isIssuable() external view override returns (bool) {
        return _isIssuable;
    }

    /**
     * @dev Definitely renounce the possibility to issue new tokens.
     * Once set to false, '_isIssuable' can never be set to 'true' again.
     */
    function renounceIssuance() external {
        _onlyAdmin(msg.sender);
        _isIssuable = false;
    }

    /**
     * @dev Know if the token can be controlled by operators.
     * If a token returns 'false' for 'isControllable()'' then it MUST always return 'false' in the future.
     * @return bool 'true' if the token can still be controlled by operators, 'false' if it can't anymore.
     */
    function isControllable() external view override returns (bool) {
        return _isControllable;
    }

    /**
     * @dev Definitely renounce the possibility to control tokens on behalf of tokenHolders.
     * Once set to false, '_isControllable' can never be set to 'true' again.
     */
    function renounceControl() external {
        _onlyAdmin(msg.sender);
        _isControllable = false;
    }

    /**
     * @dev Issue tokens from default partition.
     * @param tokenHolder Address for which we want to issue tokens.
     * @param value Number of tokens issued.
     * @param data Information attached to the issuance, by the issuer.
     */
    function issue(
        address tokenHolder,
        uint256 value,
        bytes calldata data
    ) external override {
        _onlyIssuable();
        _onlyMinter(msg.sender);
        require(_defaultPartitions.length != 0, "55"); // 0x55	funds locked (lockup period)

        _issueByPartition(
            _defaultPartitions[0],
            msg.sender,
            tokenHolder,
            value,
            data
        );
    }

    /**
     * @dev Issue tokens from a specific partition.
     * @param partition Name of the partition.
     * @param tokenHolder Address for which we want to issue tokens.
     * @param value Number of tokens issued.
     * @param data Information attached to the issuance, by the issuer.
     */
    function issueByPartition(
        bytes32 partition,
        address tokenHolder,
        uint256 value,
        bytes calldata data
    ) external override {
        _onlyIssuable();
        _onlyMinter(msg.sender);
        _issueByPartition(partition, msg.sender, tokenHolder, value, data);
    }

    /**
     * @dev Redeem the amount of tokens from the address 'msg.sender'.
     * @param value Number of tokens to redeem.
     * @param data Information attached to the redemption, by the token holder.
     */
    function redeem(uint256 value, bytes calldata data) external override {
        _onlyBurner(msg.sender);
        _redeemByDefaultPartitions(msg.sender, msg.sender, value, data);
    }

    /**
     * @dev Redeem the amount of tokens on behalf of the address from.
     * @param from Token holder whose tokens will be redeemed (or address(0) to set from to msg.sender).
     * @param value Number of tokens to redeem.
     * @param data Information attached to the redemption.
     */
    function redeemFrom(
        address from,
        uint256 value,
        bytes calldata data
    ) external override {
        _onlyBurner(msg.sender);
        require(_isOperator(msg.sender, from), "58"); // 0x58	invalid operator (transfer agent)
        _redeemByDefaultPartitions(msg.sender, from, value, data);
    }

    /**
     * @dev Redeem tokens of a specific partition.
     * @param partition Name of the partition.
     * @param value Number of tokens redeemed.
     * @param data Information attached to the redemption, by the redeemer.
     */
    function redeemByPartition(
        bytes32 partition,
        uint256 value,
        bytes calldata data
    ) external override {
        _onlyBurner(msg.sender);
        _redeemByPartition(partition, msg.sender, msg.sender, value, data, "");
    }

    /**
     * @dev Redeem tokens of a specific partition.
     * @param partition Name of the partition.
     * @param tokenHolder Address for which we want to redeem tokens.
     * @param value Number of tokens redeemed
     * @param operatorData Information attached to the redemption, by the operator.
     */
    function operatorRedeemByPartition(
        bytes32 partition,
        address tokenHolder,
        uint256 value,
        bytes calldata operatorData
    ) external override {
        _onlyBurner(msg.sender);
        require(
            _isOperatorForPartition(partition, msg.sender, tokenHolder),
            "58"
        ); // 0x58	invalid operator (transfer agent)
        _redeemByPartition(
            partition,
            msg.sender,
            tokenHolder,
            value,
            "",
            operatorData
        );
    }

    /**
     * @dev Check the value of tokens that an owner allowed to a spender.
     * @param partition Name of the partition.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the value of tokens still available for the spender.
     */
    function allowanceByPartition(
        bytes32 partition,
        address owner,
        address spender
    ) external view returns (uint256) {
        return _allowancesByPartition[partition][owner][spender];
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of 'msg.sender'.
     * @param partition Name of the partition.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean that indicates if the operation was successful.
     */
    function approveByPartition(
        bytes32 partition,
        address spender,
        uint256 value
    ) external returns (bool) {
        require(spender != address(0), "56"); // 0x56	invalid sender
        _allowancesByPartition[partition][msg.sender][spender] = value;
        emit ApprovalByPartition(partition, msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from a specific partition.
     * @param fromPartition Partition of the tokens to transfer.
     * @param operator The address performing the transfer.
     * @param from Token holder.
     * @param to Token recipient.
     * @param value Number of tokens to transfer.
     * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
     * @param operatorData Information attached to the transfer, by the operator (if any).
     * @return Destination partition.
     */
    function _transferByPartition(
        bytes32 fromPartition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal returns (bytes32) {
        require(_isMultiple(value), "50"); // 0x50	transfer failure
        require(to != address(0), "57"); // 0x57	invalid receiver
        require(_balanceOfByPartition[from][fromPartition] >= value, "52"); // 0x52	insufficient balance

        bytes32 toPartition = _getDestinationPartition(data, fromPartition);
        // Only controllers and partitioners can switch partitions
        if (
            toPartition != fromPartition &&
            !_isControllerForPartition(toPartition, operator)
        ) {
            _onlyPartitioner(operator);
        }

        _assertValidTransfer(
            fromPartition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );

        _beforeTokenTransfer(
            fromPartition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );

        _removeTokenFromPartition(from, fromPartition, value);
        _addTokenToPartition(to, toPartition, value);

        _afterTokenTransfer(
            toPartition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );

        emit TransferByPartition(
            fromPartition,
            operator,
            from,
            to,
            value,
            data,
            operatorData
        );

        if (toPartition != fromPartition) {
            emit ChangedPartition(fromPartition, toPartition, value);
        }

        return toPartition;
    }

    /**
     * @dev Transfer tokens from default partitions.
     * Function used for ERC20 retrocompatibility.
     * @param operator The address performing the transfer.
     * @param from Token holder.
     * @param to Token recipient.
     * @param value Number of tokens to transfer.
     * @param data Information attached to the transfer, and intended for the token holder ('from') [CAN CONTAIN THE DESTINATION PARTITION].
     */
    function _transferByDefaultPartitions(
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        require(_defaultPartitions.length != 0, "55"); // // 0x55	funds locked (lockup period)

        uint256 _remainingValue = value;
        uint256 _localBalance;

        for (uint256 i = 0; i < _defaultPartitions.length; i++) {
            _localBalance = _balanceOfByPartition[from][_defaultPartitions[i]];
            if (_remainingValue <= _localBalance) {
                _transferByPartition(
                    _defaultPartitions[i],
                    operator,
                    from,
                    to,
                    _remainingValue,
                    data,
                    ""
                );
                _remainingValue = 0;
                break;
            } else if (_localBalance != 0) {
                _transferByPartition(
                    _defaultPartitions[i],
                    operator,
                    from,
                    to,
                    _localBalance,
                    data,
                    ""
                );
                _remainingValue = _remainingValue - _localBalance;
            }
        }

        require(_remainingValue == 0, "52"); // 0x52	insufficient balance
    }

    /**
     * @dev Remove a token from a specific partition.
     * @param from Token holder.
     * @param partition Name of the partition.
     * @param value Number of tokens to transfer.
     */
    function _removeTokenFromPartition(
        address from,
        bytes32 partition,
        uint256 value
    ) internal {
        _balances[from] = _balances[from].sub(value);
        _totalSupply = _totalSupply.sub(value);

        _balanceOfByPartition[from][partition] = _balanceOfByPartition[from][
            partition
        ].sub(value);
        _totalSupplyByPartition[partition] = _totalSupplyByPartition[partition]
            .sub(value);

        // If the total supply is zero, finds and deletes the partition.
        if (_totalSupplyByPartition[partition] == 0) {
            uint256 index1 = _indexOfTotalPartitions[partition];
            require(index1 > 0, "50"); // 0x50	transfer failure

            // move the last item into the index being vacated
            bytes32 lastValue = _totalPartitions[_totalPartitions.length - 1];
            _totalPartitions[index1 - 1] = lastValue; // adjust for 1-based indexing
            _indexOfTotalPartitions[lastValue] = index1;

            _indexOfTotalPartitions[partition] = 0;
            _totalPartitions.pop();
        }

        // If the balance of the TokenHolder's partition is zero, finds and deletes the partition.
        if (_balanceOfByPartition[from][partition] == 0) {
            uint256 index2 = _indexOfPartitionsOf[from][partition];
            require(index2 > 0, "50"); // 0x50	transfer failure

            // move the last item into the index being vacated
            bytes32 lastValue = _partitionsOf[from][
                _partitionsOf[from].length - 1
            ];
            _partitionsOf[from][index2 - 1] = lastValue; // adjust for 1-based indexing
            _indexOfPartitionsOf[from][lastValue] = index2;

            _indexOfPartitionsOf[from][partition] = 0;
            _partitionsOf[from].pop();
        }
    }

    /**
     * @dev Add a token to a specific partition.
     * @param to Token recipient.
     * @param partition Name of the partition.
     * @param value Number of tokens to transfer.
     */
    function _addTokenToPartition(
        address to,
        bytes32 partition,
        uint256 value
    ) internal {
        if (value != 0) {
            _totalSupply = _totalSupply.add(value);
            _balances[to] = _balances[to].add(value);

            if (_indexOfPartitionsOf[to][partition] == 0) {
                _partitionsOf[to].push(partition);
                _indexOfPartitionsOf[to][partition] = _partitionsOf[to].length;
            }
            _balanceOfByPartition[to][partition] = _balanceOfByPartition[to][
                partition
            ].add(value);

            if (_indexOfTotalPartitions[partition] == 0) {
                _totalPartitions.push(partition);
                _indexOfTotalPartitions[partition] = _totalPartitions.length;
            }
            _totalSupplyByPartition[partition] = _totalSupplyByPartition[
                partition
            ].add(value);
        }
    }

    /**
     * @dev Check if 'value' is multiple of the granularity.
     * @param value The quantity that want's to be checked.
     * @return 'true' if 'value' is a multiple of the granularity.
     */
    function _isMultiple(uint256 value) internal view returns (bool) {
        return (value.div(_granularity).mul(_granularity) == value);
    }

    /**
     * @dev Indicate whether the operator address is a controller.
     * @param operator Address which may be the token controller.
     * @return 'true' if 'operator' is a controller.
     */
    function isController(address operator)
        public
        view
        override
        returns (bool)
    {
        return _isController(operator);
    }

    /**
     * @dev Indicate whether the operator address is a controller.
     * @param operator Address which may be the token controller.
     * @return 'true' if 'operator' is a controller.
     */
    function _isController(address operator) internal view returns (bool) {
        return
            _isControllable &&
            (
                (hasRole(CONTROLLER_ROLE, operator) ||
                    hasRole(ADMIN_ROLE, operator))
            );
    }

    /**
     * @dev Indicate whether the operator address is a controller for partition.
     * @param partition Name of the partition.
     * @param operator Address which may be the token controller.
     * @return 'true' if 'operator' is a controller partition.
     */
    function isControllerForPartition(bytes32 partition, address operator)
        public
        view
        override
        returns (bool)
    {
        return _isControllerForPartition(partition, operator);
    }

    /**
     * @dev Indicate whether the operator address is a controller for partition.
     * @param partition Name of the partition.
     * @param operator Address which may be the token controller.
     * @return 'true' if 'operator' is a controller partition.
     */
    function _isControllerForPartition(bytes32 partition, address operator)
        internal
        view
        returns (bool)
    {
        return
            _isControllable &&
            (
                (hasRole(
                    keccak256(abi.encodePacked(partition, CONTROLLER_ROLE)),
                    operator
                ) ||
                    hasRole(CONTROLLER_ROLE, operator) ||
                    hasRole(ADMIN_ROLE, operator))
            );
    }

    /**
     * @dev Indicate whether the operator address is an operator of the tokenHolder address.
     * @param operator Address which may be an operator of 'tokenHolder'.
     * @param tokenHolder Address of a token holder which may have the 'operator' address as an operator.
     * @return 'true' if 'operator' is an operator of 'tokenHolder' and 'false' otherwise.
     */
    function _isOperator(address operator, address tokenHolder)
        internal
        view
        returns (bool)
    {
        return (operator == tokenHolder ||
            _authorizedOperator[operator][tokenHolder] ||
            _isController(operator));
    }

    /**
     * @dev Indicate whether the operator address is an operator of the tokenHolder
     * address for the given partition.
     * @param partition Name of the partition.
     * @param operator Address which may be an operator of tokenHolder for the given partition.
     * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given partition.
     * @return 'true' if 'operator' is an operator of 'tokenHolder' for partition 'partition' and 'false' otherwise.
     */
    function _isOperatorForPartition(
        bytes32 partition,
        address operator,
        address tokenHolder
    ) internal view returns (bool) {
        return (_isOperator(operator, tokenHolder) ||
            _authorizedOperatorByPartition[tokenHolder][partition][operator] ||
            _isControllerForPartition(partition, operator));
    }

    /**
     * @dev Issue tokens from a specific partition.
     * @param toPartition Name of the partition.
     * @param operator The address performing the issuance.
     * @param to Token recipient.
     * @param value Number of tokens to issue.
     * @param data Information attached to the issuance.
     */
    function _issueByPartition(
        bytes32 toPartition,
        address operator,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        _assertValidTransfer(
            toPartition,
            operator,
            address(0),
            to,
            value,
            data,
            ""
        );

        _beforeTokenTransfer(
            toPartition,
            operator,
            address(0),
            to,
            value,
            data,
            ""
        );

        _addTokenToPartition(to, toPartition, value);

        _afterTokenTransfer(
            toPartition,
            operator,
            address(0),
            to,
            value,
            data,
            ""
        );

        emit Issued(operator, to, value, data);
        emit IssuedByPartition(toPartition, operator, to, value, data, "");
    }

    /**
     * @dev Redeem tokens of a specific partition.
     * @param fromPartition Name of the partition.
     * @param operator The address performing the redemption.
     * @param from Token holder whose tokens will be redeemed.
     * @param value Number of tokens to redeem.
     * @param data Information attached to the redemption.
     * @param operatorData Information attached to the redemption, by the operator (if any).
     */
    function _redeemByPartition(
        bytes32 fromPartition,
        address operator,
        address from,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal {
        require(_isMultiple(value), "50"); // 0x50	transfer failure
        require(from != address(0), "56"); // 0x56	invalid sender
        require(_balanceOfByPartition[from][fromPartition] >= value, "52"); // 0x52	insufficient balance

        _assertValidTransfer(
            fromPartition,
            operator,
            from,
            address(0),
            value,
            data,
            ""
        );

        _beforeTokenTransfer(
            fromPartition,
            operator,
            from,
            address(0),
            value,
            data,
            operatorData
        );

        _removeTokenFromPartition(from, fromPartition, value);

        _afterTokenTransfer(
            "",
            operator,
            from,
            address(0),
            value,
            data,
            operatorData
        );

        emit Redeemed(operator, from, value, data);
        emit RedeemedByPartition(
            fromPartition,
            operator,
            from,
            value,
            operatorData
        );
    }

    /**
     * @dev Redeem tokens from a default partitions.
     * @param operator The address performing the redeem.
     * @param from Token holder.
     * @param value Number of tokens to redeem.
     * @param data Information attached to the redemption.
     */
    function _redeemByDefaultPartitions(
        address operator,
        address from,
        uint256 value,
        bytes memory data
    ) internal {
        require(_defaultPartitions.length != 0, "55"); // 0x55	funds locked (lockup period)

        uint256 _remainingValue = value;
        uint256 _localBalance;

        for (uint256 i = 0; i < _defaultPartitions.length; i++) {
            _localBalance = _balanceOfByPartition[from][_defaultPartitions[i]];
            if (_remainingValue <= _localBalance) {
                _redeemByPartition(
                    _defaultPartitions[i],
                    operator,
                    from,
                    _remainingValue,
                    data,
                    ""
                );
                _remainingValue = 0;
                break;
            } else {
                _redeemByPartition(
                    _defaultPartitions[i],
                    operator,
                    from,
                    _localBalance,
                    data,
                    ""
                );
                _remainingValue = _remainingValue - _localBalance;
            }
        }

        require(_remainingValue == 0, "52"); // 0x52	insufficient balance
    }

    /**
     * @notice Transfers of securities may fail for a number of reasons. So this function will used to understand the
     * cause of failure by getting the byte value. Which will be the ESC that follows the EIP 1066. ESC can be mapped
     * with a reson string to understand the failure cause, table of Ethereum status code will always reside off-chain
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     * @param data The `bytes _data` allows arbitrary data to be submitted alongside the transfer.
     * @return byte Ethereum status code (ESC)
     * @return bytes32 Application specific reason code
     */
    // reduce contract size
    // function canTransfer(
    //     address to,
    //     uint256 value,
    //     bytes calldata data
    // ) external view override returns (bytes1, bytes32) {
    //     return _canTransferFrom(_msgSender(), _msgSender(), to, value, data);
    // }

    /**
     * @notice Transfers of securities may fail for a number of reasons. So this function will used to understand the
     * cause of failure by getting the byte value. Which will be the ESC that follows the EIP 1066. ESC can be mapped
     * with a reson string to understand the failure cause, table of Ethereum status code will always reside off-chain
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     * @param data The `bytes _data` allows arbitrary data to be submitted alongside the transfer.
     * @return byte Ethereum status code (ESC)
     * @return bytes32 Application specific reason code
     */
    // reduce contract size
    // function canTransferFrom(
    //     address from,
    //     address to,
    //     uint256 value,
    //     bytes calldata data
    // ) external view override returns (bytes1, bytes32) {
    //     return _canTransferFrom(_msgSender(), from, to, value, data);
    // }

    /**
     * @notice The standard provides an on-chain function to determine whether a transfer will succeed,
     * and return details indicating the reason if the transfer is not valid.
     * @param from The address from whom the tokens get transferred.
     * @param to The address to which to transfer tokens to.
     * @param partition The partition from which to transfer tokens
     * @param value The amount of tokens to transfer from `_partition`
     * @param data Additional data attached to the transfer of tokens
     * @return statusCode ESC (Ethereum Status Code) following the EIP-1066 standard
     * @return appCode Application specific reason codes with additional details
     * @return toPartition The partition to which the transferred tokens were allocated for the _to address
     */
    // reduce contract size
    // function canTransferByPartition(
    //     address from,
    //     address to,
    //     bytes32 partition,
    //     uint256 value,
    //     bytes calldata data
    // )
    //     external
    //     view
    //     override
    //     returns (
    //         bytes1 statusCode,
    //         bytes32 appCode,
    //         bytes32 toPartition
    //     )
    // {
    //     (statusCode, appCode) = _checkTransferByPartition(
    //         partition,
    //         msg.sender,
    //         from,
    //         to,
    //         value,
    //         data
    //     );

    //     toPartition = _getDestinationPartition(data, partition);
    // }

    /**
     * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
     * @param operator The address performing the transfer.
     * @param from Token holder.
     * @param to Token recipient.
     * @param value Number of tokens to transfer.
     * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
     * @return statusCode ESC (Ethereum Status Code) following the EIP-1066 standard.
     * @return appCode Additional bytes32 parameter that can be used to define
     * application specific reason codes with additional details (for example the
     * transfer restriction rule responsible for making the transfer operation invalid).
     */
    // reduce contract size
    // function _canTransferFrom(
    //     address operator,
    //     address from,
    //     address to,
    //     uint256 value,
    //     bytes memory data
    // ) internal view returns (bytes1 statusCode, bytes32 appCode) {
    //     require(_defaultPartitions.length != 0, "55"); // 0x55 funds locked (lockup period)

    //     uint256 _remainingValue = value;
    //     uint256 _localBalance = 0;

    //     for (uint256 i = 0; i < _defaultPartitions.length; i++) {
    //         bytes32 partition = _defaultPartitions[i];
    //         _localBalance = _balanceOfByPartition[from][partition];

    //         uint256 valueToTrasferFromPartition =
    //             value > _localBalance ? _localBalance : value;

    //         (statusCode, appCode) = _checkTransferByPartition(
    //             partition,
    //             operator,
    //             from,
    //             to,
    //             valueToTrasferFromPartition,
    //             data
    //         );

    //         if (!_isSuccess(statusCode)) {
    //             return (statusCode, appCode);
    //         }

    //         _remainingValue = _remainingValue > _localBalance
    //             ? _remainingValue - _localBalance
    //             : 0;
    //         if (_remainingValue == 0) {
    //             break;
    //         }
    //     }

    //     if (_remainingValue != 0) {
    //         return (bytes1(0x52), bytes32(0)); // 0x52 insufficient balance
    //     }

    //     return (bytes1(0x51), bytes32(0)); // 0x51 success
    // }

    // reduce contract size
    // function _checkTransferByPartition(
    //     bytes32 partition,
    //     address operator,
    //     address from,
    //     address to,
    //     uint256 value,
    //     bytes memory data
    // ) internal view returns (bytes1 statusCode, bytes32 appCode) {
    //     // check granularity
    //     if (!_isMultiple(value)) {
    //         return (bytes1(0x50), bytes32(0));
    //     }

    //     // check balance
    //     if (_balanceOfByPartition[from][partition] <= value) {
    //         return (bytes1(0x52), bytes32(0)); // 0x52	insufficient balance
    //     }

    //     if (
    //         // check authorized operator and controller
    //         !_isOperatorForPartition(partition, operator, from) ||
    //         // check partition allowance
    //         value > _allowancesByPartition[partition][from][msg.sender]
    //     ) {
    //         // (bytes1(0x53), bytes32(0)); // 0x53	insufficient allowance ( same as invalid operator )
    //         return (bytes1(0x58), bytes32(0)); // 0x58	invalid operator
    //     }

    //     (statusCode, appCode) = _canTransferByPartition(
    //         partition,
    //         operator,
    //         from,
    //         to,
    //         value,
    //         data
    //     );
    //     if (statusCode != 0x0 && !_isSuccess(statusCode)) {
    //         return (statusCode, appCode);
    //     }

    //     return
    //         _validateTransfer(partition, operator, from, to, value, data, "");
    // }

    /**
     * @dev Hook that is called after initial transfer checks.
     * @param partition The partition from which to transfer tokens
     * @param operator The address performing the transfer.
     * @param from Token holder.
     * @param to Token recipient.
     * @param value Number of tokens to transfer.
     * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    // reduce contract size
    // function _canTransferByPartition(
    //     bytes32 partition,
    //     address operator,
    //     address from,
    //     address to,
    //     uint256 value,
    //     bytes memory data
    // ) internal view virtual returns (bytes1, bytes32) {}

    /**
     * @dev Hook that is called before any transfer of tokens. This includes minting and burning.
     * @param partition Name of the partition (bytes32 to be left empty for transfers where partition is not specified).
     * @param operator Address which triggered the balance decrease (through transfer or redemption).
     * @param from Token holder.
     * @param to Token recipient for a transfer and 0x for a redemption.
     * @param value Number of tokens the token holder balance is decreased by.
     * @param data Extra information.
     * @param operatorData Extra information, attached by the operator (if any).
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal virtual {}

    /**
     * @dev Hook that is called before any transfer of tokens. This includes minting and burning.
     * @param partition Name of the partition (bytes32 to be left empty for transfers where partition is not specified).
     * @param operator Address which triggered the balance decrease (through transfer or redemption).
     * @param from Token holder.
     * @param to Token recipient for a transfer and 0x for a redemption.
     * @param value Number of tokens the token holder balance is decreased by.
     * @param data Extra information.
     * @param operatorData Extra information, attached by the operator (if any).
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal virtual {}
}

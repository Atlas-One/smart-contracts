// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC1644 {
    // Controller Operation
    function isControllable() external view returns (bool);

    // Custom
    function isController(address operator) external view returns (bool);

    // Custom
    function isControllerForPartition(bytes32 partition, address operator)
        external
        view
        returns (bool);

    function controllerTransfer(
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _data,
        bytes calldata _operatorData
    ) external;

    function controllerRedeem(
        address _tokenHolder,
        uint256 _value,
        bytes calldata _data,
        bytes calldata _operatorData
    ) external;

    // Controller Events
    event ControllerTransfer(
        address _controller,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );

    event ControllerRedemption(
        address _controller,
        address indexed _tokenHolder,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );
}

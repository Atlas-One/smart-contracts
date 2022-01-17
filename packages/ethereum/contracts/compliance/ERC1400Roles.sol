// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

abstract contract ERC1400Roles {
    // keccak256("CONTROLLER_ROLE")
    bytes32 public constant CONTROLLER_ROLE =
        0x7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c570223357;

    // keccak256("BURNER_ROLE")
    bytes32 public constant BURNER_ROLE =
        0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848;

    // keccak256("MINTER_ROLE")
    bytes32 public constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    // keccak256("PAUSER_ROLE")
    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;

    // keccak256("PARTITIONER_ROLE")
    bytes32 public constant PARTITIONER_ROLE =
        0xaaa92300dc6b8a00567e94016220ab4a3570eef9a665b6d7804fca19be9bca08;

    uint256[50] private __gap;
}

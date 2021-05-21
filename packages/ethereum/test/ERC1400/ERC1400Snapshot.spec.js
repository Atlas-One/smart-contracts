const { BN, expectEvent, expectRevert } = require("@openzeppelin/test-helpers");
const ERC1400SnapshotMock = artifacts.require("ERC1400SnapshotMock");

contract("ERC1400Snapshot", function ([initialHolder, recipient, other]) {
  const initialSupply = new BN(100);

  beforeEach(async function () {
    this.token = await ERC1400SnapshotMock.new(
      "My Token",
      "MTKN",
      initialHolder,
      initialSupply,
      [],
      [],
      []
    );
  });

  describe("totalSupplyAt", function () {});

  describe("balanceOfAt", function () {});
});

const { BN } = require("@openzeppelin/test-helpers");
const ERC1400OwnershipSnapshotMock = artifacts.require(
  "ERC1400OwnershipSnapshotMock"
);

contract(
  "ERC1400OwnershipSnapshot",
  function ([initialHolder, recipient, other]) {
    const initialSupply = new BN(100);

    beforeEach(async function () {
      this.token = await ERC1400OwnershipSnapshotMock.new(
        "My Token",
        "MTKN",
        initialHolder,
        initialSupply,
        [],
        [],
        []
      );
    });

    describe("issueOwned", function () {});

    describe("describeOwnership", function () {});
  }
);

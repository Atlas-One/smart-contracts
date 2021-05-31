const { BN } = require("@openzeppelin/test-helpers");
const ERC1400OwnershipSnapshotMock = artifacts.require(
  "ERC1400OwnershipSnapshotMock"
);

// keccak256("issued")
const issuedPartition =
  "0x73662fd7bbdf693b73934bcf2352cab3e780f0e307af257c8932afcd4c892500";

contract("ERC1400OwnershipSnapshot", function ([deployer, holder]) {
  const initialSupply = new BN(100);
  let token;

  beforeEach(async function () {
    token = await ERC1400OwnershipSnapshotMock.new(
      "My Token",
      "MTKN",
      holder,
      initialSupply,
      [],
      [],
      [],
      {
        from: deployer,
      }
    );
  });

  describe.only("issue", () => {
    it("should have created an ownership timestamp for the holder", async () => {
      const { amount } = await token.ownerships(holder, 0);
      assert.equal(amount.toString(), initialSupply.toString());
    });
  });

  describe("issueOwned", function () {
    it("should issue and set the ownership timestamp to the provided timestamp", async () => {});
  });

  describe("describeOwnership", function () {
    it("should issue and set the ownership timestamp to the provided timestamp", async () => {
      await token.issueByPartition(
        issuedPartition,
        holder,
        initialSupply * 2,
        "0x",
        {
          from: deployer,
        }
      );
      const { amounts: amounts1 } = await token.describeOwnership(
        holder,
        initialSupply
      );

      console.log(amounts1);

      assert.equal(amounts1.length, 1);
      assert.equal(amounts1[0].toString(), initialSupply.toString());

      const { amounts: amounts2 } = await token.describeOwnership(
        holder,
        2 * initialSupply
      );

      assert.equal(amounts2.length, 2);
      assert.equal(amounts2[0].toString(), initialSupply.toString());
      assert.equal(amounts2[1].toString(), initialSupply.toString());
    });
  });
});

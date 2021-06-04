const { BN } = require("@openzeppelin/test-helpers");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const GeneralTransferManager = artifacts.require("GeneralTransferManager");
const ERC1400_ERC20Compatible = artifacts.require("ERC1400_ERC20Compatible");
const VestingEscrowWallet = artifacts.require("VestingEscrowWallet");

const MINTER_ROLE =
  "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";
const BURNER_ROLE =
  "0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848";

contract(
  "VestingEscrowWallet",
  function ([deployer, beneficiary, beneficiary2]) {
    beforeEach(async () => {
      this.gtm = await deployProxy(GeneralTransferManager, {
        from: deployer,
      });
      this.vestingWallet = await VestingEscrowWallet.new({
        from: deployer,
      });
      this.token = await ERC1400_ERC20Compatible.new(
        "My Token",
        "MTKN",
        1,
        [],
        [],
        [this.gtm.address],
        {
          from: deployer,
        }
      );

      await this.token.grantRole(MINTER_ROLE, this.vestingWallet.address, {
        from: deployer,
      });
      await this.token.grantRole(BURNER_ROLE, this.vestingWallet.address, {
        from: deployer,
      });

      // allow the vesting wallet to hold security tokens
      await this.gtm.addToAllowlist(this.vestingWallet.address, {
        from: deployer,
      });
      await this.gtm.addToAllowlist(beneficiary, {
        from: deployer,
      });
      await this.gtm.addToAllowlist(beneficiary2, {
        from: deployer,
      });
    });

    describe.only("vest", () => {
      it("should mint/issue and add vesting schedule", async () => {
        await this.vestingWallet.vest(
          this.token.address,
          beneficiary,
          "0xc07f330d2eb486dda2afcf7f468ebcb22181a6b6e51d02bf5872b650731b01ed",
          new BN(100),
          1622677982,
          1811980382,
          1633218782
        );

        assert.equal(
          (await this.token.balanceOf(this.vestingWallet.address)).toString(),
          "100"
        );
      });
    });
    describe.only("vestMultiple", () => {
      it("should mint/issue and add vesting schedule", async () => {
        await this.vestingWallet.vestMultiple(
          [this.token.address, this.token.address],
          [beneficiary, beneficiary2],
          [
            "0xc07f330d2eb486dda2afcf7f468ebcb22181a6b6e51d02bf5872b650731b01ed",
            "0xc07f330d2eb486dda2afcf7f468ebcb22181a6b6e51d02bf5872b650731b01ed",
          ],
          [new BN(100), new BN(200)],
          [1622677982, 1622677982],
          [1811980382, 1811980382],
          [1633218782, 1633218782]
        );

        assert.equal(
          (await this.token.balanceOf(this.vestingWallet.address)).toString(),
          "300"
        );
      });
    });
  }
);

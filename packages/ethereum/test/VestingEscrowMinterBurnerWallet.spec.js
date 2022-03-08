const Web3 = require("web3");
const { BN, time } = require("@openzeppelin/test-helpers");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const WhitelistUpgradeable = artifacts.require("WhitelistUpgradeable");
const WhitelistValidator = artifacts.require("WhitelistValidator");
const SecurityToken = artifacts.require("SecurityToken");
const VestingEscrowMinterBurnerWallet = artifacts.require(
  "VestingEscrowMinterBurnerWallet"
);

const MINTER_ROLE =
  "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";
const BURNER_ROLE =
  "0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848";

contract(
  "VestingEscrowMinterBurnerWallet",
  function ([deployer, beneficiary, beneficiary2]) {
    beforeEach(async function () {
      this.whitelist = await deployProxy(WhitelistUpgradeable, {
        from: deployer,
      });
      this.whitelistValidator = await deployProxy(WhitelistValidator, [this.whitelist.address], {
        from: deployer,
      });
      this.vestingWallet = await VestingEscrowMinterBurnerWallet.new({
        from: deployer,
      });
      this.token = await SecurityToken.new(
        {
          name: "My Token",
          symbol: "MTKN",
          granularity: 1,
          decimals: 18,
          defaultPartitions: [],
          admins: [],
          controllers: [],
          validators: [],
          burners: [this.vestingWallet.address],
          minters: [this.vestingWallet.address],
          pausers: [this.vestingWallet.address],
          partitioners: [this.vestingWallet.address]
        },
        {
          from: deployer,
        }
      );

      await this.whitelist.addToWhitelist(this.token.address, beneficiary, {
        from: deployer,
      });
      await this.whitelist.addToWhitelist(this.token.address, beneficiary2, {
        from: deployer,
      });
    });

    describe("vest", function () {
      it("should mint/issue and add vesting schedule", async function () {
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

    describe("vestMultiple", function () {
      it("should mint/issue and add vesting schedule", async function () {
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
    describe("claim", function () {
      it("should claim tokens", async function () {
        await this.vestingWallet.vest(
          this.token.address,
          beneficiary,
          "0xc07f330d2eb486dda2afcf7f468ebcb22181a6b6e51d02bf5872b650731b01ed",
          new BN(100),
          1622677982,
          1811980382,
          1633218782
        );

        await time.increaseTo(1811980382);

        await this.vestingWallet.claim({ from: beneficiary });
        assert.equal(
          (await this.token.balanceOf(beneficiary)).toString(),
          "100"
        );
        assert.equal(
          (
            await this.token.balanceOfByPartition(
              Web3.utils.fromAscii("vested"),
              beneficiary
            )
          ).toString(),
          "100"
        );
      });
    });
  }
);

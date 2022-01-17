const { expectRevert } = require("@openzeppelin/test-helpers");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const SecurityToken = artifacts.require("SecurityToken");
const Whitelist = artifacts.require("Whitelist");
const WhitelistValidator = artifacts.require("WhitelistValidator");

const EMPTY_DATA = "0x";
const ZERO_BYTE = "0x";

const MINTER_ROLE =
  "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";
const BURNER_ROLE =
  "0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848";
const CONTROLLER_ROLE =
  "0x7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c570223357";
const PAUSER_ROLE =
  "0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a";
const VALIDATOR_ROLE =
  "0xa95257aebefccffaada4758f028bce81ea992693be70592f620c4c9a0d9e715a";

const partition1_short =
  "7265736572766564000000000000000000000000000000000000000000000000"; // reserved in hex
const partition2_short =
  "6973737565640000000000000000000000000000000000000000000000000000"; // issued in hex
const partition3_short =
  "6c6f636b65640000000000000000000000000000000000000000000000000000"; // locked in hex
const partition1 = "0x".concat(partition1_short);
const partition2 = "0x".concat(partition2_short);
const partition3 = "0x".concat(partition3_short);

const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const partitions = [partition1, partition2, partition3];

const issuanceAmount = 1000;

const assertTotalSupply = async (_contract, _amount) => {
  totalSupply = await _contract.totalSupply();
  assert.equal(totalSupply, _amount);
};

const assertBalanceOf = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  await assertBalance(_contract, _tokenHolder, _amount);
  await assertBalanceOfByPartition(
    _contract,
    _tokenHolder,
    _partition,
    _amount
  );
};

const assertBalanceOfByPartition = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  balanceByPartition = await _contract.balanceOfByPartition(
    _partition,
    _tokenHolder
  );
  assert.equal(balanceByPartition, _amount);
};

const assertBalance = async (_contract, _tokenHolder, _amount) => {
  balance = await _contract.balanceOf(_tokenHolder);
  assert.equal(balance, _amount);
};

contract(
  "SecurityToken",
  function ([owner, operator, controller, tokenHolder, recipient, unknown]) {
    before(async function () {
      this.whitelist = await deployProxy(Whitelist, {
        from: owner,
      });
      this.whitelistValidator = await deployProxy(WhitelistValidator, [this.whitelist.address], {
        from: owner,
      });
    });

    beforeEach(async function () {
      this.token = await SecurityToken.new(
        "SecurityToken",
        "TEST",
        1,
        18,
        partitions,
        [],
        [controller],
        [],
        [],
        [],
        [],
        []
      );

      await this.token.grantRoles(this.whitelistValidator.address, [VALIDATOR_ROLE], {
        from: owner,
      });
    });

    // ISSUE 

    describe("tokenHoldersCount", function () {
      it("should have added to the token holders count", async function () {
        await this.token.issue(tokenHolder, issuanceAmount, ZERO_BYTES32, {
          from: owner,
        });
        const tokenHoldersCount = await this.token.tokenHoldersCount();
        assert.equal(tokenHoldersCount.toString(), "1");
        const address = await this.token.tokenHolder(0);
        assert.equal(address, tokenHolder);
      });
    });

    // PAUSER

    describe("pauser role", function () {
      describe("addPauser/removePauser", function () {
        describe("add/renounce a pauser", function () {
          describe("when caller is a pauser", function () {
            it("adds a pauser as token owner", async function () {
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
              await this.token.grantRole(PAUSER_ROLE, unknown, {
                from: owner,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                true
              );
            });
            it("adds a pauser as token controller", async function () {
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
              await this.token.grantRole(PAUSER_ROLE, unknown, {
                from: owner,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                true
              );
            });
            it("adds a pauser as pauser", async function () {
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
              await this.token.grantRole(PAUSER_ROLE, unknown, {
                from: owner,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                true
              );

              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, tokenHolder),
                false
              );
              await this.token.grantRole(PAUSER_ROLE, tokenHolder, {
                from: owner,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, tokenHolder),
                true
              );
            });
            it("renounces pauser", async function () {
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
              await this.token.grantRole(PAUSER_ROLE, unknown, {
                from: owner,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                true
              );
              await this.token.renounceRole(PAUSER_ROLE, unknown, {
                from: unknown,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
            });
          });
          describe("when caller is not a pauser", function () {
            it("reverts", async function () {
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
              await expectRevert.unspecified(
                this.token.grantRole(PAUSER_ROLE, unknown, {
                  from: unknown,
                })
              );
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
            });
          });
        });
        describe("remove a pauser", function () {
          describe("when caller is a pauser", function () {
            it("adds a pauser as token owner", async function () {
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
              await this.token.grantRole(PAUSER_ROLE, unknown, {
                from: owner,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                true
              );
              await this.token.revokeRole(PAUSER_ROLE, unknown, {
                from: owner,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                false
              );
            });
          });
          describe("when caller is not a pauser", function () {
            it("reverts", async function () {
              assert.equal(
                await this.token.hasRole(
                  PAUSER_ROLE,

                  unknown
                ),
                false
              );
              await this.token.grantRole(PAUSER_ROLE, unknown, {
                from: owner,
              });
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                true
              );
              await expectRevert.unspecified(
                this.token.revokeRole(PAUSER_ROLE, unknown, {
                  from: tokenHolder,
                })
              );
              assert.equal(
                await this.token.hasRole(PAUSER_ROLE, unknown),
                true
              );
            });
          });
        });
      });
      describe("pause", function () {
        beforeEach(async function () {
          this.whitelistValidator = await deployProxy(WhitelistValidator, {
            from: owner,
          });
          this.token = await SecurityToken.new(
            "SecurityToken",
            "TEST",
            1,
            18,
            partitions,
            [],
            [controller],
            [this.whitelistValidator.address],
            [],
            [],
            [],
            "0x0000000000000000000000000000000000000000"
          );

          await this.whitelist.addToWhitelist(tokenHolder, {
            from: owner,
          });
          await this.token.issue(tokenHolder, issuanceAmount, ZERO_BYTES32, {
            from: owner,
          });
          await this.token.authorizeOperator(operator, {
            from: tokenHolder,
          });

          await this.token.pause({
            from: owner,
          });
        });
        describe("when owner pauses the contract", function () {
          const amount = 100;
          it("token holder should not be able to transfer", async function () {
            await expectRevert.unspecified(
              this.token.transfer(recipient, amount, {
                from: tokenHolder,
              })
            );
          });
          it("operator should not be able to transfer", async function () {
            await expectRevert.unspecified(
              this.token.transferFrom(tokenHolder, recipient, amount, {
                from: operator,
              })
            );
          });
          it("controller should be able to transfer", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await this.token.controllerTransfer(
              tokenHolder,
              recipient,
              amount,
              ZERO_BYTES32,
              ZERO_BYTES32,
              {
                from: owner,
              }
            );
          });
          it("account with ADMIN_ROLE should be able to transfer", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await this.token.transferFrom(tokenHolder, recipient, amount, {
              from: owner,
            });
          });
        });
      });
    });

    // ALLOWLIST EXTENSION
    describe("allowlist", function () {
      const redeemAmount = 50;
      const transferAmount = 300;
      beforeEach(async function () {
        await this.token.hasRole(VALIDATOR_ROLE, this.whitelistValidator.address);

        await this.whitelist.addToWhitelist(tokenHolder, {
          from: owner,
        });

        await this.token.issueByPartition(
          partition1,
          tokenHolder,
          issuanceAmount,
          EMPTY_DATA,
          { from: owner }
        );
      });
      describe("ERC1400 functions", function () {
        describe("issue", function () {
          it("issues new tokens when recipient is allowlisted", async function () {
            await this.token.issue(tokenHolder, issuanceAmount, EMPTY_DATA, {
              from: owner,
            });
            await assertTotalSupply(this.token, 2 * issuanceAmount);
            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              2 * issuanceAmount
            );
          });
          it("fails issuing when recipient is not allowlisted", async function () {
            await this.whitelist.removeFromWhitelist(tokenHolder, {
              from: owner,
            });
            await expectRevert.unspecified(
              this.token.issue(tokenHolder, issuanceAmount, EMPTY_DATA, {
                from: owner,
              })
            );
          });
        });
        describe("issueByPartition", function () {
          it("issues new tokens when recipient is allowlisted", async function () {
            await this.token.issueByPartition(
              partition1,
              tokenHolder,
              issuanceAmount,
              EMPTY_DATA,
              { from: owner }
            );
            await assertTotalSupply(this.token, 2 * issuanceAmount);
            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              2 * issuanceAmount
            );
          });
          it("fails issuing when recipient is not allowlisted", async function () {
            await this.whitelist.removeFromWhitelist(tokenHolder, {
              from: owner,
            });
            await expectRevert.unspecified(
              this.token.issueByPartition(
                partition1,
                tokenHolder,
                issuanceAmount,
                EMPTY_DATA,
                { from: owner }
              )
            );
          });
        });
        describe("redeem", function () {
          it("should fail to redeem the requested amount when sender is token holder and has no BURNER_ROLE (redeem effectively burns tokens)", async function () {
            await expectRevert.unspecified(
              this.token.redeem(issuanceAmount, EMPTY_DATA, {
                from: tokenHolder,
              })
            );
          });
        });
        describe("redeemFrom", function () {
          it("should fail to redeem the requested amount when authorizeOperator is token holder and has no BURNER_ROLE (redeem effectively burns tokens)", async function () {
            await this.token.authorizeOperator(operator, { from: tokenHolder });
            await expectRevert.unspecified(
              this.token.redeemFrom(tokenHolder, issuanceAmount, EMPTY_DATA, {
                from: operator,
              })
            );
            await expectRevert.unspecified(
              this.token.redeemByPartition(
                partition1,
                redeemAmount,
                EMPTY_DATA,
                { from: operator }
              )
            );
          });
        });
        describe("redeemByPartition", function () {
          it("should fail to redeem the requested amount when sender is token holder and has no BURNER_ROLE (redeem effectively burns tokens)", async function () {
            await expectRevert.unspecified(
              this.token.redeemByPartition(
                partition1,
                redeemAmount,
                EMPTY_DATA,
                { from: tokenHolder }
              )
            );
          });
        });
        describe("operatorRedeemByPartition", function () {
          it("should fail to redeem the requested amount when authorizeOperator is token holder and has no BURNER_ROLE (redeem effectively burns tokens)", async function () {
            await this.token.authorizeOperatorByPartition(
              partition1,
              operator,
              {
                from: tokenHolder,
              }
            );
            await expectRevert.unspecified(
              this.token.operatorRedeemByPartition(
                partition1,
                tokenHolder,
                redeemAmount,
                EMPTY_DATA,
                { from: operator }
              )
            );
          });
        });
        describe("transferWithData", function () {
          it("transfers the requested amount when sender and recipient are allowlisted", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await this.token.transferWithData(
              recipient,
              transferAmount,
              EMPTY_DATA,
              { from: tokenHolder }
            );

            await assertBalance(
              this.token,
              tokenHolder,
              issuanceAmount - transferAmount
            );
            await assertBalance(this.token, recipient, transferAmount);
          });
          it("fails transferring when sender is not allowlisted", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await this.whitelist.removeFromWhitelist(tokenHolder, {
              from: owner,
            });
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await expectRevert.unspecified(
              this.token.transferWithData(
                recipient,
                transferAmount,
                EMPTY_DATA,
                { from: tokenHolder }
              )
            );

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);
          });
          it("fails transferring when recipient is not allowlisted", async function () {
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await this.whitelist.removeFromWhitelist(recipient, {
              from: owner,
            });
            await assertBalance(this.token, recipient, 0);

            await expectRevert.unspecified(
              this.token.transferWithData(
                recipient,
                transferAmount,
                EMPTY_DATA,
                { from: tokenHolder }
              )
            );

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);
          });
        });
        describe("transferFromWithData", function () {
          it("transfers the requested amount when sender and recipient are allowliste", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await this.token.authorizeOperator(operator, { from: tokenHolder });
            await this.token.transferFromWithData(
              tokenHolder,
              recipient,
              transferAmount,
              EMPTY_DATA,
              { from: operator }
            );

            await assertBalance(
              this.token,
              tokenHolder,
              issuanceAmount - transferAmount
            );
            await assertBalance(this.token, recipient, transferAmount);
          });
        });
        describe("transferByPartition", function () {
          it("transfers the requested amount when sender and recipient are allowlisted", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              issuanceAmount
            );
            await assertBalanceOf(this.token, recipient, partition1, 0);

            await this.token.transferByPartition(
              partition1,
              recipient,
              transferAmount,
              EMPTY_DATA,
              { from: tokenHolder }
            );

            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              issuanceAmount - transferAmount
            );
            await assertBalanceOf(
              this.token,
              recipient,
              partition1,
              transferAmount
            );
          });
          it("fails transferring when sender is not allowlisted", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await this.whitelist.removeFromWhitelist(tokenHolder, {
              from: owner,
            });
            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              issuanceAmount
            );
            await assertBalanceOf(this.token, recipient, partition1, 0);

            await expectRevert.unspecified(
              this.token.transferByPartition(
                partition1,
                recipient,
                transferAmount,
                EMPTY_DATA,
                { from: tokenHolder }
              )
            );

            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              issuanceAmount
            );
            await assertBalanceOf(this.token, recipient, partition1, 0);
          });
          it("fails transferring when recipient is not allowlisted", async function () {
            await this.whitelist.removeFromWhitelist(recipient, {
              from: owner,
            });
            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              issuanceAmount
            );
            await assertBalanceOf(this.token, recipient, partition1, 0);

            await expectRevert.unspecified(
              this.token.transferByPartition(
                partition1,
                recipient,
                transferAmount,
                EMPTY_DATA,
                { from: tokenHolder }
              )
            );

            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              issuanceAmount
            );
            await assertBalanceOf(this.token, recipient, partition1, 0);
          });
        });
        describe("operatorTransferByPartition", function () {
          it("transfers the requested amount when sender and recipient are allowlisted", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              issuanceAmount
            );
            await assertBalanceOf(this.token, recipient, partition1, 0);
            assert.equal(
              await this.token.allowanceByPartition(
                partition1,
                tokenHolder,
                operator
              ),
              0
            );

            const approvedAmount = 400;
            await this.token.approveByPartition(
              partition1,
              operator,
              approvedAmount,
              { from: tokenHolder }
            );
            assert.equal(
              await this.token.allowanceByPartition(
                partition1,
                tokenHolder,
                operator
              ),
              approvedAmount
            );
            await this.token.operatorTransferByPartition(
              partition1,
              tokenHolder,
              recipient,
              transferAmount,
              ZERO_BYTE,
              EMPTY_DATA,
              { from: operator }
            );

            await assertBalanceOf(
              this.token,
              tokenHolder,
              partition1,
              issuanceAmount - transferAmount
            );
            await assertBalanceOf(
              this.token,
              recipient,
              partition1,
              transferAmount
            );
            assert.equal(
              await this.token.allowanceByPartition(
                partition1,
                tokenHolder,
                operator
              ),
              approvedAmount - transferAmount
            );
          });
        });
      });
      describe("ERC20 functions", function () {
        describe("transfer", function () {
          it("transfers the requested amount when sender and recipient are allowlisted", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await this.token.transfer(recipient, transferAmount, {
              from: tokenHolder,
            });

            await assertBalance(
              this.token,
              tokenHolder,
              issuanceAmount - transferAmount
            );
            await assertBalance(this.token, recipient, transferAmount);
          });
          it("fails transferring when sender and is not allowlisted", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await this.whitelist.removeFromWhitelist(tokenHolder, {
              from: owner,
            });
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await expectRevert.unspecified(
              this.token.transfer(recipient, transferAmount, {
                from: tokenHolder,
              })
            );

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);
          });
          it("fails transferring when recipient and is not allowlisted", async function () {
            await this.whitelist.removeFromWhitelist(recipient, {
              from: owner,
            });
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await expectRevert.unspecified(
              this.token.transfer(recipient, transferAmount, {
                from: tokenHolder,
              })
            );

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);
          });
        });
        describe("transferFrom", function () {
          it("transfers the requested amount when sender and recipient are allowlisted", async function () {
            await this.whitelist.addToWhitelist(recipient, {
              from: owner,
            });
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await this.token.authorizeOperator(operator, { from: tokenHolder });
            await this.token.transferFrom(
              tokenHolder,
              recipient,
              transferAmount,
              {
                from: operator,
              }
            );

            await assertBalance(
              this.token,
              tokenHolder,
              issuanceAmount - transferAmount
            );
            await assertBalance(this.token, recipient, transferAmount);
          });
          it("fails transferring when sender is not allowlisted", async function () {
            await this.whitelist.removeFromWhitelist(tokenHolder, {
              from: owner,
            });
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await this.token.authorizeOperator(operator, { from: tokenHolder });
            await expectRevert.unspecified(
              this.token.transferFrom(tokenHolder, recipient, transferAmount, {
                from: operator,
              })
            );

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);
          });
          it("fails transferring when recipient is not allowlisted", async function () {
            await this.whitelist.removeFromWhitelist(recipient, {
              from: owner,
            });
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await this.token.authorizeOperator(operator, { from: tokenHolder });
            await expectRevert.unspecified(
              this.token.transferFrom(tokenHolder, recipient, transferAmount, {
                from: operator,
              })
            );

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);
          });
        });
      });
    });
  }
);

<!-- @format -->

# Atlas One Tezos Smart contracts

Tezos controlled and permissioned asset.

## Development

<https://teztnets.xyz/>

<https://smartpy.io/docs/>
<https://smartpy.io/docs/cli>

## Access Control

See the access control design doc [here](/docs/tezos/access-control-design.md) for explanation behind the access control.

### Token Roles

| Role            | On Chain Value |
| --------------- | -------------- |
| ADMIN_ROLE      | 0              |
| CONTROLLER_ROLE | 1              |
| MINTER_ROLE     | 2              |
| BURNER_ROLE     | 3              |
| PAUSER_ROLE     | 4              |
| VALIDATOR_ROLE  | 5              |

### TransferList Roles

| Role                 | On Chain Value |
| -------------------- | -------------- |
| ADMIN_ROLE           | 0              |
| WHITELIST_ADMIN_ROLE | 1              |
| BLACKLIST_ADMIN_ROLE | 2              |

## Deployed Contracts

### Deployed on SmartPy Jakartanet

Deployer: tz1REZKzqhR7sJxH5JTY8Y6zJeh93GKpLJHf

| Contract                        | Address                              |
| ------------------------------- | ------------------------------------ |
| Whitelist                       | KT1A5io8djC3x2XQDK7a8virqBLSsRd1gEm6 |
| WhitelistValidator              | KT1NBUssF7tcZSgF3zm8N61wMoPHdb7domfV |
| VestingEscrowMinterBurnerWallet | KT1Un2fTccdR23U88jRiEoRJWFdXxJReYtkX |

## Development

You can use and explore the deployed smart ccontracts above on tzkt example <https://jakartanet.tzkt.io/KT1A5io8djC3x2XQDK7a8virqBLSsRd1gEm6>.

See the explorer documentations I found useful from <https://api.tzkt.io/#tag/Contracts>.

I found working on the smartpy web ide sufficient to test and write the logic.

- <https://smartpy.io/ide>
- <https://smartpy.io/reference.html>

### Test

Run the command `yarn test` which will run the `test.sh` script.
The test output folder is `smartpy-test-output`.

### Compiling

To compile run `sh ./compile.sh`.
If you add a new contract, be sure to add it to the compile.sh file.

### Faucets

- Mainnet Faucet <https://faucet.tezos.com/>
- Testnet Faucet <https://faucet.tzalpha.net/>

### Faucet Accounts

You can find the faucet accounts in `keystore/accounts.js`. The acccounts have been activated and the test networks so no need to acll the `scripts/activate.js`. Also, the secret keys are already added to the `keystore/accounts.js` file using the script `scripts/secretKey.js`.

IMPORTANT: Don't use these accounts for anything else.

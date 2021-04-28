# Atlas One Smart Contracts

Atlas One Smart Contracts is a suite of smart contracts adopted by Atlas One to support the creation and issuance of a controlled and permissed asset i.e. Digital Security Offering (DSO). The token contracts are compatible with the ERC20 and FA1.2 standards. The suite of contracts allow minting/burning tokens, pausing transfer activities, and ability to extend/share transfer restrictions.

## Access Control / Roles

Using [OpenZeppelin's Access Control](https://docs.openzeppelin.com/contracts/4.x/access-control) logic and design, the folowing roles are implemented for both Tezos and Ethereum. There can be multiple accounts per role using the Access Control.

| Role           | Description                                                                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Administrators | This role can act as the burner, minter and controller. It is also the only role that can grant and revoke roles.                                                        |
| Controllers    | This role can operate on all tokens without permission as an intervention e.g. recover tokens from another wallet.                                                       |
| Minters        | This role is granted to accounts or contracts that can mint tokens.                                                                                                      |
| Burners        | This role can be granted to any account of contract that can burn tokens.                                                                                                |
| Validators     | The validator role is granted to another contract only that has restrictions set to validate a transaction. The current restriction is a shared Whitelist and Blacklist. |
| Pauser         | This role can pause transactions. Only controllers can perform transactions when a contract is paused.                                                                   |
| Operators      | Token holders are operators of their own token. A token holder can grant another account the operator role to their tokens.                                              |

### Granting, Revoking and Renouncing Roles

The deployer is initially granted the administrator role in the Ethereum Contract but with Tezos, the storage can be initiatiated with multiple roles preconfigured. The administrator is the only role that can grant/revoke roles using the `grantRole` and `revokeRole` entrypoints. At role member has the ability to renounce their role using the `renounceRole` entrypoint.

> NOTE: Atlas One maintains an administrative role to manage a token for an issuer.

## Transfer Validation

The tokens share an Allowlist of whitelisted and blacklisted addresses. The list maintains it own access control roles:

| Role                       | Description                                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Administrators             | This role can act as both the allow and block list roles. This is the only role that can grant/revoke roles. |
| Allowedlist Administrators | This role can modify the allowed list.                                                                       |
| Blocklist Administrators   | This role can modify the blocked list.                                                                       |

Granting, revoking and renoucng roles is similar to the explanation above.

> NOTE: A controller/administrator can force transfer out of a blocklisted address

## Pausing

Contract transfers can be paused except for the controller in order to perform any intervention actions. Control can be renounced by admin using the entrypoint `renounceControl`.

## Minting

Minters can mint tokens as long as the contract can still issue tokens. Issuance can be renounced by the admin using the entrypoint `renounceIssuance`.

## Burning

Burners can burn tokens at any time.

## Redeeming

The current redemption stratergy is for a burner to burn the tokens after an off chain agreement.

## Meta/Feeless Transactions

The current stratergy is to make use of the controller role to perform a transfer on behalf of the token holder when they make an off chain transfer request. The TZIP-017 and EIP712 were not adopted in this suite but could be adopted to support feeless transactions without using the controller role.

Refrence Implementations:

- EIP712 MetaTransaction https://github.com/bcnmy/metatx-standard/blob/master/src/contracts/EIP712MetaTransaction.sol
- Gas Station Network (GSN) https://docs.openzeppelin.com/learn/sending-gasless-transactions
- Smartpy Permits/TZIP-017 https://github.com/EGuenz/smartpy-permits
- Ligo StableCoin Permits https://github.com/tqtezos/stablecoin
- Smartpy StableCoin with Feeless Transactions https://gitlab.com/tezos-paris-hub/eurotz-euro-stable-coin

## Upgrading

TBD

## Deactivating Token

TBD

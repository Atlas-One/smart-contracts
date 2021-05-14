<!-- @format -->

# Access Control Design

We implemented the Access Control by drawing inpiration from [OpenZeppelin's Access Control](https://docs.openzeppelin.com/contracts/4.x/access-control). The storage is expected as:

```python
sp.record(
    role_admin = sp.TNat,
    members = sp.map(
        tkey=sp.TNat,
        tvalue=sp.TRecord(
            role_admin=sp.TNat,
            members=sp.TSet(
                t=sp.TAddress
            )
        )
    )
)
```

## Entrypoints

- `assertRole`
- `grantRole`
- `revokeRoke`
- `renounceRole`

## Motivation

A validation contract can use `assertRole` for the operator and make decisions based on the restrictions e.g. and operator who is a controller can perform force transactions set by the implemented TZIP-15 Transferlist.

An alternative design to `assertRole` is to pass a list of the operators `roles`. This would reuire to either:

- storage to keep track of the roles that an account is a member of
- or loop through each role and collect the roles to send to the entry point

The current implementation does not send the roles to the validators `assertTransfer`. The current storage allows for the `assertTransfer` call to quickly access and loop through the `members` with the `VALIDATOR_ROLE`.

> Note that the `VALIDATOR_ROLE` should always be granted to a smart contract that implements the entrypoint `assertTransfer (operator, (from_, to_))`.

import smartpy as sp


ADMIN_ROLE = 0
CONTROLLER_ROLE = 1
MINTER_ROLE = 2
BURNER_ROLE = 3
PAUSER_ROLE = 4
VALIDATOR_ROLE = 5


def make_role(role_admin, members=sp.set([], t=sp.TAddress)):
    return sp.record(
        role_admin = role_admin,
        members = members
    )


def make_roles(administrators, validators, controllers):
    return sp.map(
        {
            ADMIN_ROLE: make_role(ADMIN_ROLE, administrators),
            CONTROLLER_ROLE: make_role(ADMIN_ROLE, controllers),
            MINTER_ROLE: make_role(ADMIN_ROLE),
            BURNER_ROLE: make_role(ADMIN_ROLE),
            PAUSER_ROLE: make_role(ADMIN_ROLE),
            VALIDATOR_ROLE: make_role(ADMIN_ROLE, validators)
        },
        tkey=sp.TNat, 
        tvalue=sp.TRecord(
            role_admin=sp.TNat,
            members=sp.TSet(t=sp.TAddress)
        )
    )


class AccessControl(sp.Contract):
    
    def has_role(self, role, account):
        return (self.data.roles.contains(role) & self.data.roles[role].members.contains(account))
    
    def sender_has_role(self, role):
        return self.has_role(role, sp.sender)
    
    @sp.entry_point
    def assertRole(self, params):
        sp.verify(self.has_role(params.role, params.account))
    
    @sp.entry_point
    def grantRole(self, params):
        sp.for p in params:
            sp.verify(self.sender_has_role(self.data.roles[p.role].role_admin))
            sp.if ~self.has_role(p.role, p.account):
                self.data.roles[p.role].members.add(p.account)
    
    @sp.entry_point
    def revokeRole(self, params):
        sp.for p in params:
            sp.verify(self.sender_has_role(self.data.roles[p.role].role_admin))
            sp.if self.has_role(p.role, p.account):
                self.data.roles[p.role].members.remove(p.account)
    
    @sp.entry_point
    def renounceRole(self, params):
        sp.for p in params:
            sp.verify(p.account == sp.sender)
            sp.if self.has_role(p.role, p.account):
                self.data.roles[p.role].members.remove(p.account)


class Pausable(AccessControl):
    
    def is_paused(self):
        return self.data.paused

    @sp.entry_point
    def pause(self):
        sp.verify(self.sender_has_role(PAUSER_ROLE) | self.sender_has_role(ADMIN_ROLE))
        self.data.paused = True

    @sp.entry_point
    def resume(self):
        sp.verify(self.sender_has_role(PAUSER_ROLE) | self.sender_has_role(ADMIN_ROLE))


class Controller(AccessControl):

    def is_controller(self, account):
        return (
            self.data.controllable & 
            (self.has_role(CONTROLLER_ROLE, account) | self.has_role(ADMIN_ROLE, account))
        )
    
    @sp.entry_point
    def renounceControl(self):
        sp.verify(self.sender_has_role(ADMIN_ROLE))
        
        self.data.controllable = False


class Mintable(AccessControl):

    def is_minter(self):
        return (self.sender_has_role(MINTER_ROLE) | self.sender_has_role(ADMIN_ROLE))

    @sp.sub_entry_point
    def _mint(self, params):
        sp.set_type(params, 
            sp.TRecord(
                address=sp.TAddress,
                amount=sp.TNat,
                token_id=sp.TNat,
                metadata=sp.TMap(sp.TString, sp.TBytes),
            )
        )
        
        # verify issuable
        sp.verify(self.data.issuable)
        
        if self.config.single_asset:
            sp.verify(params.token_id == 0, "single-asset: token-id <> 0")
        if self.config.non_fungible:
            sp.verify(params.amount == 1, "NFT-asset: amount <> 1")
            sp.verify(
                ~self.token_id_set.contains(
                    self.data.all_tokens,
                    params.token_id
                ),
                "NFT-asset: cannot mint twice same token"
            )
            
        user = self.ledger_key.make(params.address, params.token_id)
        
        self.token_id_set.add(self.data.all_tokens, params.token_id)
        
        sp.if self.data.ledger.contains(user):
            self.data.ledger[user].balance += params.amount
        sp.else:
            self.data.ledger[user] = Ledger_value.make(params.amount)
        
        sp.if self.data.tokens.contains(params.token_id):
            self.data.tokens[params.token_id].total_supply += params.amount
        sp.else:
            self.data.tokens[params.token_id] = self.token_meta_data.make(
                amount = params.amount,
                metadata = params.metadata
            )

    # a.k.a issue / issueMultiple
    @sp.entry_point
    def mint(self, params):
        sp.verify(self.is_minter())

        sp.for p in params:
            self._mint(p)
    
    @sp.entry_point
    def renounceIssuance(self):
        sp.verify(self.sender_has_role(ADMIN_ROLE))
        
        self.data.issuable = False


class Burnable(AccessControl):
                        
    def is_burner(self):
        return (self.sender_has_role(BURNER_ROLE) | self.sender_has_role(ADMIN_ROLE))

    @sp.sub_entry_point
    def _burn(self, params):
        sp.set_type(params, 
            sp.TRecord(
                address=sp.TAddress,
                amount=sp.TNat,
                token_id=sp.TNat,
            )
        )
        
        sp.verify(self.sender_has_role(ADMIN_ROLE))
        
        # We don't check for pauseness because we're the admin.
        if self.config.single_asset:
            sp.verify(params.token_id == 0, "single-asset: token-id <> 0")
        if self.config.non_fungible:
            sp.verify(params.amount == 1, "NFT-asset: amount <> 1")
            sp.verify(
                self.token_id_set.contains(
                    self.data.all_tokens,
                    params.token_id
                ),
                "NFT-asset: does not exist"
            )

        user = self.ledger_key.make(params.address, params.token_id)
        
        # We don't need to remove token_id_set to preserve assume_consecutive_token_ids
        # self.token_id_set.remove(self.data.all_tokens, params.token_id)

        sp.verify(self.data.ledger.contains(user))
        sp.verify(self.data.ledger[user].balance > params.amount)
        self.data.ledger[user].balance = sp.as_nat(self.data.ledger[user].balance - params.amount)
        
        self.data.tokens[params.token_id].total_supply = sp.as_nat(self.data.tokens[params.token_id].total_supply - params.amount)

    # a.k.a redeem / redeemMultiple
    @sp.entry_point
    def burn(self, params):
        sp.verify(self.is_burner())

        sp.for p in params:
            self._burn(p)


class Ledger_key:
    
    def __init__(self, config):
        self.config = config
        
    def make(self, user, token):
        user = sp.set_type_expr(user, sp.TAddress)
        token = sp.set_type_expr(token, token_id_type)
        
        if self.config.single_asset:
            result = user
        else:
            result = sp.pair(user, token)
            
        if self.config.readable:
            return result
        else:
            return sp.pack(result)


class Ledger_value:
   
    def get_type():
        return sp.TRecord(
            balance=sp.TNat
        )

    def make(balance):
        return sp.record(balance=balance)


class Ledger(sp.Contract):
    def __init__(self, debug_mode, **extra_storage):

        if debug_mode:
            self.ledger_map = sp.map
        else:
            self.ledger_map = sp.big_map

        self.init(
            ledger=self.ledger_map(tvalue=Ledger_value.get_type()),
            **extra_storage
        )

    def decrease_and_remove_balance_if_necessary(self, key, amount):
        sp.if self.data.ledger.contains(key):
            self.data.ledger[key].balance = sp.as_nat(self.data.ledger[key].balance - amount)
            sp.if self.data.ledger[key].balance <= 0:
                del self.data.ledger[key]


class Transferlist(AccessControl):

    def assertTransfer(self, params):
        sp.set_type(params, sp.TRecord(from_ = sp.TAddress, to_ = sp.TAddress))
        sp.for validator in self.data.roles[VALIDATOR_ROLE].members.elements():
            c = sp.contract(
                t = sp.TRecord(
                    from_=sp.TAddress,
                    to_=sp.TAddress,
                    operator=sp.TAddress
                ), 
                address = validator, 
                entry_point = "assertTransfer"
            ).open_some()
                        
            sp.transfer(
                sp.record(
                    from_=params.from_,
                    to_=params.to_,
                    operator=sp.sender
                ),
                sp.mutez(0),
                c
            )
                
                
##
## ## Meta-Programming Configuration
##
## The `FA2_config` class holds the meta-programming configuration.
##
class FA2_config:
    def __init__(self,
                 debug_mode                   = False,
                 single_asset                 = False,
                 non_fungible                 = False,
                 readable                     = True,
                 force_layouts                = True,
                 assume_consecutive_token_ids = True,
                 lazy_entry_points = False,
                 lazy_entry_points_multiple = False
                 ):
                     
        self.debug_mode = debug_mode
        
        if debug_mode:
            self.my_map = sp.map
        else:
            self.my_map = sp.big_map
        # The option `debug_mode` makes the code generation use
        # regular maps instead of big-maps, hence it makes inspection
        # of the state of the contract easier.

        self.single_asset = single_asset
        # This makes the contract save some gas and storage by
        # working only for the token-id `0`.

        self.non_fungible = non_fungible
        # Enforce the non-fungibility of the tokens, i.e. the fact
        # that total supply has to be 1.

        self.readable = readable
        # The `readable` option is a legacy setting that we keep around
        # only for benchmarking purposes.
        #
        # User-accounts are kept in a big-map:
        # `(user-address * token-id) -> ownership-info`.
        #
        # For the Babylon protocol, one had to use `readable = False`
        # in order to use `PACK` on the keys of the big-map.

        self.force_layouts = force_layouts
        # The specification requires all interface-fronting records
        # and variants to be *right-combs;* we keep
        # this parameter to be able to compare performance & code-size.

        self.assume_consecutive_token_ids = assume_consecutive_token_ids
        # For a previous version of the TZIP specification, it was
        # necessary to keep track of the set of all tokens in the contract.
        #
        # The set of tokens is for now still available; this parameter
        # guides how to implement it:
        # If `true` we don't need a real set of token ids, just to know how
        # many there are.

        self.lazy_entry_points = lazy_entry_points
        self.lazy_entry_points_multiple = lazy_entry_points_multiple
        #
        # Those are “compilation” options of SmartPy into Michelson.
        #
        if lazy_entry_points and lazy_entry_points_multiple:
            raise Exception(
                "Cannot provide lazy_entry_points and lazy_entry_points_multiple")

        name = "FA2"
        if debug_mode:
            name += "-debug"
        if single_asset:
            name += "-single_asset"
        if non_fungible:
            name += "-nft"
        if not readable:
            name += "-no_readable"
        if not force_layouts:
            name += "-no_layout"
        if not assume_consecutive_token_ids:
            name += "-no_toknat"
        if lazy_entry_points:
            name += "-lep"
        if lazy_entry_points_multiple:
            name += "-lepm"
        self.name = name

## ## Auxiliary Classes and Values
##
## The definitions below implement SmartML-types and functions for various
## important types.
##
token_id_type = sp.TNat

class Error_message:
    def __init__(self, config):
        self.config = config
        self.prefix = "FA2_"
    def make(self, s): return (self.prefix + s)
    def token_undefined(self):       return self.make("TOKEN_UNDEFINED")
    def insufficient_balance(self):  return self.make("INSUFFICIENT_BALANCE")
    def not_operator(self):          return self.make("NOT_OPERATOR")
    def not_owner(self):             return self.make("NOT_OWNER")
    def operators_unsupported(self): return self.make("OPERATORS_UNSUPPORTED")
    def controllers_unsupported(self): return self.make("CONTROLLERS_UNSUPPORTED")

## The current type for a batched transfer in the specification is as
## follows:
##
## ```ocaml
## type transfer = {
##   from_ : address;
##   txs: {
##     to_ : address;
##     token_id : token_id;
##     amount : nat;
##   } list
## } list
## ```
##
## This class provides helpers to create and force the type of such elements.
## It uses the `FA2_config` to decide whether to set the right-comb layouts.
class Batch_transfer:
    def __init__(self, config):
        self.config = config
    
    def get_transfer_type(self):
        tx_type = sp.TRecord(
            to_ = sp.TAddress,
            token_id = token_id_type,
            amount = sp.TNat
        )
        if self.config.force_layouts:
            tx_type = tx_type.layout(
                ("to_", ("token_id", "amount"))
            )
        transfer_type = sp.TRecord(
            from_ = sp.TAddress,
            txs = sp.TList(tx_type)
        ).layout(
            ("from_", "txs")
        )
        return transfer_type
    
    def get_type(self):
        return sp.TList(self.get_transfer_type())
    
    def item(self, from_, txs):
        v = sp.record(from_ = from_, txs = txs)
        return sp.set_type_expr(v, self.get_transfer_type())
##
## `Operator_param` defines type types for the `%update_operators` entry-point.
class Operator_param:
    def __init__(self, config):
        self.config = config
    
    def get_type(self):
        t = sp.TRecord(
            owner = sp.TAddress,
            operator = sp.TAddress,
            token_id = token_id_type
        )
        if self.config.force_layouts:
            t = t.layout(("owner", ("operator", "token_id")))
        return t
    
    def make(self, owner, operator, token_id):
        r = sp.record(
            owner = owner,
            operator = operator,
            token_id = token_id
        )
        return sp.set_type_expr(r, self.get_type())


## The link between operators and the addresses they operate is kept
## in a *lazy set* of `(owner × operator × token-id)` values.
##
## A lazy set is a big-map whose keys are the elements of the set and
## values are all `Unit`.
class Operator_set:

    def __init__(self, config):
        self.config = config

    def inner_type(self):
        return sp.TRecord(
            owner = sp.TAddress,
            operator = sp.TAddress,
            token_id = token_id_type
        ).layout(("owner", ("operator", "token_id")))
    
    def key_type(self):
        if self.config.readable:
            return self.inner_type()
        else:
            return sp.TBytes
    
    def make(self):
        return self.config.my_map(tkey = self.key_type(), tvalue = sp.TUnit)
    
    def make_key(self, owner, operator, token_id):
        metakey = sp.record(
            owner = owner,
            operator = operator,
            token_id = token_id
        )
        metakey = sp.set_type_expr(metakey, self.inner_type())
        if self.config.readable:
            return metakey
        else:
            return sp.pack(metakey)
    
    def add(self, set, owner, operator, token_id):
        set[self.make_key(owner, operator, token_id)] = sp.unit
    
    def remove(self, set, owner, operator, token_id):
        del set[self.make_key(owner, operator, token_id)]
    
    def is_member(self, set, owner, operator, token_id):
        return set.contains(self.make_key(owner, operator, token_id))

class Balance_of:
    def request_type():
        return sp.TRecord(
            owner = sp.TAddress,
            token_id = token_id_type
        ).layout(("owner", "token_id"))
    
    def response_type():
        return sp.TList(
            sp.TRecord(
                request = Balance_of.request_type(),
                balance = sp.TNat
            ).layout(("request", "balance"))
        )
    
    def entry_point_type():
        return sp.TRecord(
            callback = sp.TContract(Balance_of.response_type()),
            requests = sp.TList(Balance_of.request_type())
        ).layout(("requests", "callback"))

class Token_meta_data:
    def __init__(self, config):
        self.config = config

    def get_type(self):
        return (
            sp.TRecord(
                total_supply = sp.TNat,
                token_info = sp.TMap(
                    sp.TString,
                    sp.TBytes
                )
            )
        )

    def set_type_and_layout(self, expr):
        sp.set_type(expr, self.get_type())

    def get_metadata(self, expr):
        return expr.token_info

    def make(self, amount, metadata):
        return sp.record(
            total_supply = amount,
            token_info = metadata
        )


## The set of all tokens is represented by a `nat` if we assume that token-ids
## are consecutive, or by an actual `(set nat)` if not.
##
## - Knowing the set of tokens is useful for throwing accurate error messages.
## - Previous versions of the specification required this set for functional
##   behavior (operators interface had to deal with “all tokens”).
class Token_id_set:
    def __init__(self, config):
        self.config = config
    
    def empty(self):
        if self.config.assume_consecutive_token_ids:
            # The "set" is its cardinal.
            return sp.nat(0)
        else:
            return sp.set(t = token_id_type)
    
    def add(self, metaset, v):
        if self.config.assume_consecutive_token_ids:
            sp.verify(metaset == v, "Token-IDs should be consecutive")
            metaset.set(sp.max(metaset, v + 1))
        else:
            metaset.add(v)
    
    def contains(self, metaset, v):
        if self.config.assume_consecutive_token_ids:
            return (v < metaset)
        else:
            return metaset.contains(v)
    
    def cardinal(self, metaset):
        if self.config.assume_consecutive_token_ids:
            return metaset
        else:
            return sp.len(metaset)


##
## The `FA2` class builds a contract according to an `FA2_config` and an
## administrator address.
## It is inheriting from `FA2_core` which implements the strict
## standard and a few other classes to add other common features.
##
## - We see the use of
##   [`sp.entry_point`](https://www.smartpy.io/dev/reference.html#_entry_points)
##   as a function instead of using annotations in order to allow
##   optional entry points.
## - The storage field `metadata_string` is a placeholder, the build
##   system replaces the field annotation with a specific version-string, such
##   as `"version_20200602_tzip_b916f32"`: the version of FA2-smartpy and
##   the git commit in the TZIP [repository](https://gitlab.com/tzip/tzip) that
##   the contract should obey.
class FA2_core(Ledger):
    def __init__(self, config, metadata, **extra_storage):
        
        self.config = config
        self.error_message = Error_message(self.config)
        self.operator_set = Operator_set(self.config)
        self.operator_param = Operator_param(self.config)
        self.token_id_set = Token_id_set(self.config)
        self.ledger_key = Ledger_key(self.config)
        self.token_meta_data = Token_meta_data(self.config)
        self.batch_transfer    = Batch_transfer(self.config)

        if config.lazy_entry_points:
            self.add_flag("lazy-entry-points", "single")

        if config.lazy_entry_points_multiple:
            self.add_flag("lazy-entry-points", "multiple")

        self.exception_optimization_level = "default-line"

        Ledger.__init__(
            self,
            debug_mode=self.config.debug_mode,
            tokens =
                self.config.my_map(tvalue = self.token_meta_data.get_type()),
            operators = self.operator_set.make(),
            all_tokens = self.token_id_set.empty(),
            metadata = metadata,
            **extra_storage
        )

    @sp.sub_entry_point
    def _transfer(self, params):
        sp.set_type(params, 
            sp.TRecord(
                token_id = sp.TNat,
                from_ = sp.TAddress,
                to_ = sp.TAddress,
                amount = sp.TNat
            ))
        
        sp.verify(params.amount > 0, message = "TRANSFER_OF_ZERO")
            
        sp.if self.is_paused():
            sp.verify(self.is_controller(sp.sender))
        
        self.assertTransfer(
            sp.record(
                from_=params.from_, 
                to_=params.to_
            )
        )
        
        if self.config.single_asset:
            sp.verify(params.token_id == 0, "single-asset: token-id <> 0")
        
        sp.verify(
            (self.is_controller(sp.sender)) |
            (params.from_ == sp.sender) |
            self.operator_set.is_member(
                self.data.operators,
                params.from_,
                sp.sender,
                params.token_id
            ),
            message = self.error_message.not_operator()
        )
        
        sp.verify(
            self.data.tokens.contains(params.token_id),
            message = self.error_message.token_undefined()
        )
        
        # if amount is 0 we do nothing now:
        sp.if (params.amount > 0):
            from_user = self.ledger_key.make(params.from_, params.token_id)
            
            sp.verify(
                (self.data.ledger[from_user].balance >= params.amount),
                message = self.error_message.insufficient_balance()
            )
                
            to_user = self.ledger_key.make(params.to_, params.token_id)
            
            self.data.ledger[from_user].balance = sp.as_nat(
                self.data.ledger[from_user].balance - params.amount)
            sp.if self.data.ledger.contains(to_user):
                self.data.ledger[to_user].balance += params.amount
            sp.else:
                 self.data.ledger[to_user] = Ledger_value.make(params.amount)
        sp.else:
            pass

    @sp.entry_point
    def transfer(self, params):
        sp.set_type(params, self.batch_transfer.get_type())
        
        sp.for transfer in params:
            sp.for tx in transfer.txs:
                self._transfer(
                    sp.record(
                        from_ = transfer.from_,
                        to_ = tx.to_,
                        amount = tx.amount,
                        token_id = tx.token_id
                    )
                )

    @sp.entry_point
    def transferMultiple(self, params):
        sp.for p in params:
            self._transfer(p)

    @sp.entry_point
    def balance_of(self, params):
        sp.set_type(params, Balance_of.entry_point_type())
        def f_process_request(req):
            user = self.ledger_key.make(req.owner, req.token_id)
        
            sp.verify(
                self.data.tokens.contains(req.token_id),
                message = self.error_message.token_undefined()
            )
            
            sp.result(
                sp.record(
                    request = sp.record(
                        owner = sp.set_type_expr(req.owner, sp.TAddress),
                        token_id = sp.set_type_expr(req.token_id, sp.TNat)
                    ),
                    balance = self.data.ledger[user].balance
                )
            )
        
        res = sp.local("responses", params.requests.map(f_process_request))
        destination = sp.set_type_expr(
            params.callback,
            sp.TContract(Balance_of.response_type())
        )
        sp.transfer(res.value, sp.mutez(0), destination)

    @sp.offchain_view(pure = True)
    def get_balance(self, req):
        """This is the `get_balance` view defined in TZIP-12."""
        sp.set_type(
            req, sp.TRecord(
                owner = sp.TAddress,
                token_id = sp.TNat
            ).layout(
                ("owner", "token_id")
            )
        )
            
        user = self.ledger_key.make(req.owner, req.token_id)
        
        sp.verify(
            self.data.tokens.contains(req.token_id),
            message = self.error_message.token_undefined()
        )
        
        sp.result(self.data.ledger[user].balance)


    @sp.entry_point
    def update_operators(self, params):
        sp.set_type(
            params,
            sp.TList(
                sp.TVariant(
                    add_operator = self.operator_param.get_type(),
                    remove_operator = self.operator_param.get_type()
                )
            )
        )
        
        sp.for update in params:
            with update.match_cases() as arg:
                with arg.match("add_operator") as upd:
                    sp.verify(
                        (upd.owner == sp.sender) |
                        (self.sender_has_role(ADMIN_ROLE))
                    )
                    self.operator_set.add(
                        self.data.operators,
                        upd.owner,
                        upd.operator,
                        upd.token_id
                    )
                with arg.match("remove_operator") as upd:
                    sp.verify(
                        (upd.owner == sp.sender) |
                        (self.sender_has_role(ADMIN_ROLE))
                    )
                    self.operator_set.remove(
                        self.data.operators,
                        upd.owner,
                        upd.operator,
                        upd.token_id
                    )


class TokenMetadata(FA2_core):
    @sp.offchain_view(pure = True)
    def tokens(self, tok):
        """
        Return the token-metadata URI for the given token.

        For a reference implementation, dynamic-views seem to be the
        most flexible choice.
        """
        sp.set_type(tok, sp.TNat)
        sp.result(
            sp.pair(
                tok + 0,
                self.token_meta_data.get_metadata(self.data.tokens[tok])
            )
        )

    def make_metadata(symbol, name, decimals):
        "Helper function to build metadata JSON bytes values."
        return (sp.map(l = {
            # Remember that michelson wants map already in ordered
            "decimals" : sp.bytes_of_string("%d" % decimals),
            "name" : sp.bytes_of_string(name),
            "symbol" : sp.bytes_of_string(symbol)
        }))


class ST2(
    TokenMetadata,
    Controller,
    Transferlist,
    Mintable,
    Burnable,
    Pausable,
    FA2_core):

    @sp.offchain_view(pure = True)
    def count_tokens(self):
        """Get how many tokens are in this FA2 contract.
        """
        sp.result(self.token_id_set.cardinal(self.data.all_tokens))

    @sp.offchain_view(pure = True)
    def does_token_exist(self, tok):
        "Ask whether a token ID is exists."
        sp.set_type(tok, sp.TNat)
        sp.result(self.data.tokens.contains(tok))

    @sp.offchain_view(pure = True)
    def all_tokens(self):
        if self.config.assume_consecutive_token_ids:
            sp.result(sp.range(0, self.data.all_tokens))
        else:
            sp.result(self.data.all_tokens.elements())

    @sp.offchain_view(pure = True)
    def total_supply(self, tok):
        sp.result(self.data.tokens[tok].total_supply)

    @sp.offchain_view(pure = True)
    def is_operator(self, query):
        sp.set_type(
            query,
            sp.TRecord(
                token_id = sp.TNat,
                owner = sp.TAddress,
                operator = sp.TAddress
            ).layout(("owner", ("operator", "token_id")))
        )
        sp.result(
            self.operator_set.is_member(
                self.data.operators,
                query.owner,
                query.operator,
                query.token_id
            )
        )

    def __init__(
        self,
        config,
        metadata,
        administrators=sp.set([], t=sp.TAddress),
        validators=sp.set([], t=sp.TAddress),
        controllers=sp.set([], t=sp.TAddress)):
        # Let's show off some meta-programming:
        if config.assume_consecutive_token_ids:
            self.all_tokens.doc = """
            This view is specified (but optional) in the standard.

            This contract is built with assume_consecutive_token_ids =
            True, so we return a list constructed from the number of tokens.
            """
        else:
            self.all_tokens.doc = """
            This view is specified (but optional) in the standard.

            This contract is built with assume_consecutive_token_ids =
            False, so we convert the set of tokens from the storage to a list
            to fit the expected type of TZIP-16.
            """
        list_of_views = [
            self.get_balance
            , self.tokens
            , self.does_token_exist
            , self.count_tokens
            , self.all_tokens
            , self.is_operator
            , self.total_supply
        ]
        metadata_base = {
            "version": config.name # will be changed if using fatoo.
            , "description" : (
                "This is a didactic reference implementation of FA2,"
                + " a.k.a. TZIP-012, using SmartPy.\n\n"
                + "This particular contract uses the configuration named: "
                + config.name + "."
            )
            , "interfaces": ["TZIP-012-2020-12-24"]
            , "authors": [
                "Seb Mondet <https://seb.mondet.org>",
                "Atlas One <https://atlasone.ca>"
            ]
            , "homepage": "https://github.com/Atlas-One/smart-contracts"
            , "views": list_of_views
            , "source": {
                "tools": ["SmartPy"]
                , "location": "https://github.com/Atlas-One/smart-contracts/tree/master/packages/tezos"
            }
            , "permissions": {
                "controller": "administrator-or-controller-transfer",
                "minter": "administrator-or-minter-role-mint",
                "burner": "administrator-or-burner-role-burn",
                "operator": "administrator-or-controller-or-operator-transfer",
                "receiver": "owner-no-hook",
                "sender": "owner-no-hook"
            }
            , "fa2-smartpy": {
                "configuration" :
                dict([(k, getattr(config, k)) for k in dir(config) if "__" not in k and k != 'my_map'])
            }
        }
        self.init_metadata("metadata_base", metadata_base)
        FA2_core.__init__(
            self, 
            config, 
            metadata,
            paused = False,
            issuable = True,
            controllable = True,
            # access control
            roles=make_roles(
                administrators=administrators, 
                validators=validators,
                controllers=controllers
            )
        )
    
    @sp.entry_point
    def set_metdata(self, k, v):
        sp.verify(self.sender_has_role(ADMIN_ROLE))
        self.data.metadata[k] = v


## ## Tests
##
## ### Auxiliary Consumer Contract
##
## This contract is used by the tests to be on the receiver side of
## callback-based entry-points.
## It stores facts about the results in order to use `scenario.verify(...)`
## (cf.
##  [documentation](https://www.smartpy.io/dev/reference.html#_in_a_test_scenario_)).
class View_consumer(sp.Contract):
    def __init__(self, contract):
        self.contract = contract
        self.init(last_sum = 0)

    @sp.entry_point
    def reinit(self):
        self.data.last_sum = 0
        # It's also nice to make this contract have more than one entry point.

    @sp.entry_point
    def receive_balances(self, params):
        sp.set_type(params, Balance_of.response_type())
        self.data.last_sum = 0
        sp.for resp in params:
            self.data.last_sum += resp.balance

## ### Generation of Test Scenarios
##
## Tests are also parametrized by the `FA2_config` object.
## The best way to visualize them is to use the online IDE
## (<https://www.smartpy.io/dev/>).
def add_test(config, is_default = True):
    @sp.add_test(name = config.name, is_default = is_default)
    def test():
        scenario = sp.test_scenario()
        scenario.h1("FA2 Contract Name: " + config.name)
        scenario.table_of_contents()
        
        # sp.test_account generates ED25519 key-pairs deterministically:
        admin = sp.test_account("AccessControl")
        alice = sp.test_account("Alice")
        bob   = sp.test_account("Robert")
        
        # Let's display the accounts:
        scenario.h2("Accounts")
        scenario.show([admin, alice, bob])

        c1 = ST2(
            config = config,
            administrators = sp.set([admin.address]),
            metadata = sp.metadata_of_url("https://example.com")
        )
        
        scenario += c1
        
        if config.non_fungible:
            # TODO
            return
        
        scenario.h2("Initial Minting")
        scenario.p("The administrator mints 100 token-0's to Alice.")
        tok0_md = ST2.make_metadata(
            name     = "The Token Zero",
            symbol   = "TK0",
            decimals = 2
        )
        scenario += c1.mint(
            [
                sp.record(
                    address = alice.address,
                    amount = 100,
                    metadata = tok0_md,
                    token_id = 0
                )
            ]
        ).run(sender = admin)
        
        scenario.h2("Transfers Alice -> Bob")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(
                    from_ = alice.address,
                    txs = [
                        sp.record(
                            to_ = bob.address,
                            amount = 10,
                            token_id = 0
                        )
                    ]
                )
            ]).run(sender = alice)
        
        scenario.verify(
            c1.data.ledger[c1.ledger_key.make(alice.address, 0)].balance == 90)
        scenario.verify(
            c1.data.ledger[c1.ledger_key.make(bob.address, 0)].balance == 10)
            
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(
                    from_ = alice.address,
                    txs = [
                        sp.record(
                            to_ = bob.address,
                            amount = 10,
                            token_id = 0
                        ),
                        sp.record(
                            to_ = bob.address,
                            amount = 11,
                            token_id = 0
                        )
                    ]
                )
            ]
        ).run(sender = alice)
        
        scenario.verify(
            c1.data.ledger[c1.ledger_key.make(alice.address, 0)].balance
            == 90 - 10 - 11)
        scenario.verify(
            c1.data.ledger[c1.ledger_key.make(bob.address, 0)].balance
            == 10 + 10 + 11)
        
        if config.single_asset:
            return
        
        scenario.h2("More Token Types")
        scenario += c1.mint(
            sp.list(
                [
                    sp.record(
                        address = bob.address,
                        amount = 100,
                        token_id = 1,
                        metadata = ST2.make_metadata(
                            name = "The Second Token",
                            decimals = 0,
                            symbol= "TK1"
                        ),
                    ),
                    sp.record(
                        address = bob.address,
                        amount = 200,
                        token_id = 2,
                        metadata = ST2.make_metadata(
                            name = "The Token Number Three",
                            decimals = 0,
                            symbol= "TK2"
                        ),
                    )
                ]
            )
        ).run(sender = admin)
        
        scenario.h3("Multi-token Transfer Bob -> Alice")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(
                    from_ = bob.address,
                    txs = [
                        sp.record(
                            to_ = alice.address,
                            amount = 10,
                            token_id = 0
                        ),
                        sp.record(
                            to_ = alice.address,
                            amount = 10,
                            token_id = 1
                        )
                    ]
                ),
                # We voluntarily test a different sub-batch:
                c1.batch_transfer.item(
                    from_ = bob.address,
                    txs = [
                        sp.record(
                            to_ = alice.address,
                            amount = 10,
                            token_id = 2
                        )
                    ]
                )
            ]
        ).run(sender = bob)
        
        scenario.h2("Other Basic Permission Tests")
        scenario.h3("Bob cannot transfer Alice's tokens.")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(
                    from_ = alice.address,
                    txs = [
                        sp.record(
                            to_ = bob.address,
                            amount = 10,
                            token_id = 0
                        ),
                        sp.record(
                            to_ = bob.address,
                            amount = 1,
                            token_id = 0
                        )
                    ]
                )
            ]
        ).run(sender = bob, valid = False)
        
        scenario.h3("Admin can transfer anything.")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(
                    from_ = alice.address,
                    txs = [
                        sp.record(
                            to_ = bob.address,
                            amount = 10,
                            token_id = 0
                        ),
                        sp.record(
                            to_ = bob.address,
                            amount = 10,
                            token_id = 1
                        )
                    ]
                ),
                c1.batch_transfer.item(
                    from_ = bob.address,
                    txs = [
                        sp.record(
                            to_ = alice.address,
                            amount = 11,
                            token_id = 0
                        )
                    ]
                )
            ]
        ).run(sender = admin)
        
        scenario.h3("Even Admin cannot transfer too much.")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(from_ = alice.address,
                                    txs = [
                                        sp.record(to_ = bob.address,
                                                  amount = 1000,
                                                  token_id = 0)])
            ]).run(sender = admin, valid = False)
        scenario.h3("Consumer Contract for Callback Calls.")
        consumer = View_consumer(c1)
        scenario += consumer
        scenario.p("Consumer virtual address: "
                   + consumer.address.export())
        scenario.h2("Balance-of.")
        def arguments_for_balance_of(receiver, reqs):
            return (
                sp.record(
                    callback = sp.contract(
                        Balance_of.response_type(),
                        receiver.address,
                        entry_point = "receive_balances").open_some(),
                    requests = reqs
                )
            )
        scenario += c1.balance_of(arguments_for_balance_of(consumer, [
            sp.record(owner = alice.address, token_id = 0),
            sp.record(owner = alice.address, token_id = 1),
            sp.record(owner = alice.address, token_id = 2)
        ]))
        scenario.verify(consumer.data.last_sum == 90)
        scenario.h2("Operators")
        scenario.p("This version was compiled with operator support.")
        scenario.p("Calling 0 updates should work:")
        scenario += c1.update_operators([]).run()
        scenario.h3("Operator Accounts")
        op0 = sp.test_account("Operator0")
        op1 = sp.test_account("Operator1")
        op2 = sp.test_account("Operator2")
        scenario.show([op0, op1, op2])
        scenario.p("Admin can change Alice's operator.")
        scenario += c1.update_operators([
            sp.variant("add_operator", c1.operator_param.make(
                owner = alice.address,
                operator = op1.address,
                token_id = 0)),
            sp.variant("add_operator", c1.operator_param.make(
                owner = alice.address,
                operator = op1.address,
                token_id = 2))
        ]).run(sender = admin)
        scenario.p("Operator1 can now transfer Alice's tokens 0 and 2")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(from_ = alice.address,
                                    txs = [
                                        sp.record(to_ = bob.address,
                                                  amount = 2,
                                                  token_id = 0),
                                        sp.record(to_ = op1.address,
                                                  amount = 2,
                                                  token_id = 2)])
            ]).run(sender = op1)
        scenario.p("Operator1 cannot transfer Bob's tokens")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(from_ = bob.address,
                                    txs = [
                                        sp.record(to_ = op1.address,
                                                  amount = 2,
                                                  token_id = 1)])
            ]).run(sender = op1, valid = False)
        scenario.p("Operator2 cannot transfer Alice's tokens")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(from_ = alice.address,
                                    txs = [
                                        sp.record(to_ = bob.address,
                                                  amount = 2,
                                                  token_id = 1)])
            ]).run(sender = op2, valid = False)
        scenario.p("Alice can remove their operator")
        scenario += c1.update_operators([
            sp.variant("remove_operator", c1.operator_param.make(
                owner = alice.address,
                operator = op1.address,
                token_id = 0)),
            sp.variant("remove_operator", c1.operator_param.make(
                owner = alice.address,
                operator = op1.address,
                token_id = 0))
        ]).run(sender = alice)
        scenario.p("Operator1 cannot transfer Alice's tokens any more")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(from_ = alice.address,
                                    txs = [
                                        sp.record(to_ = op1.address,
                                                  amount = 2,
                                                  token_id = 1)])
            ]).run(sender = op1, valid = False)
        scenario.p("Bob can add Operator0.")
        scenario += c1.update_operators([
            sp.variant("add_operator", c1.operator_param.make(
                owner = bob.address,
                operator = op0.address,
                token_id = 0)),
            sp.variant("add_operator", c1.operator_param.make(
                owner = bob.address,
                operator = op0.address,
                token_id = 1))
        ]).run(sender = bob)
        scenario.p("Operator0 can transfer Bob's tokens '0' and '1'")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(from_ = bob.address,
                                    txs = [
                                        sp.record(to_ = alice.address,
                                                  amount = 1,
                                                  token_id = 0)]),
                c1.batch_transfer.item(from_ = bob.address,
                                    txs = [
                                        sp.record(to_ = alice.address,
                                                  amount = 1,
                                                  token_id = 1)])
            ]).run(sender = op0)
        scenario.p("Bob cannot add Operator0 for Alice's tokens.")
        scenario += c1.update_operators([
            sp.variant("add_operator", c1.operator_param.make(
                owner = alice.address,
                operator = op0.address,
                token_id = 0
            ))
        ]).run(sender = bob, valid = False)
        scenario.p("Alice can also add Operator0 for their tokens 0.")
        scenario += c1.update_operators([
            sp.variant("add_operator", c1.operator_param.make(
                owner = alice.address,
                operator = op0.address,
                token_id = 0
            ))
        ]).run(sender = alice, valid = True)
        scenario.p("Operator0 can now transfer Bob's and Alice's 0-tokens.")
        scenario += c1.transfer(
            [
                c1.batch_transfer.item(
                    from_ = bob.address,
                    txs = [
                        sp.record(to_ = alice.address,
                            amount = 1,
                            token_id = 0
                        )
                    ]
                ),
                c1.batch_transfer.item(
                    from_ = alice.address,
                    txs = [
                        sp.record(
                            to_ = bob.address,
                            amount = 1,
                            token_id = 0
                        )
                    ]
                )
            ]
        ).run(sender = op0)
        scenario.p("Bob adds Operator2 as second operator for 0-tokens.")
        scenario += c1.update_operators(
            [
                sp.variant("add_operator", c1.operator_param.make(
                    owner = bob.address,
                    operator = op2.address,
                    token_id = 0
                ))
            ]
        ).run(sender = bob, valid = True)
        scenario.p("Operator0 and Operator2 can transfer Bob's 0-tokens.")
        scenario += c1.transferMultiple(
            [
                sp.record(
                    from_ = bob.address,
                    to_ = alice.address,
                    amount = 1,
                    token_id = 0
                )
            ]
        ).run(sender = op0)
        scenario += c1.transferMultiple(
            [
                sp.record(
                    from_ = bob.address,
                    to_ = alice.address,
                    amount = 1,
                    token_id = 0
                )
            ]
        ).run(sender = op2)
        scenario.p("Burn")
        scenario += c1.burn( 
           [
                sp.record(
                    address = bob.address,
                    amount = 1,
                    token_id = 0
                )
            ]
        ).run(sender = admin)
        scenario += c1.burn(
            [
                sp.record(
                    address = alice.address,
                    amount = 1,
                    token_id = 0
                ),
                sp.record(
                    address = bob.address,
                    amount = 1,
                    token_id = 0
                )
            ]
        ).run(sender = admin)
        scenario.table_of_contents()

##
## ## Global Environment Parameters
##
## The build system communicates with the python script through
## environment variables.
## The function `environment_config` creates an `FA2_config` given the
## presence and values of a few environment variables.
def global_parameter(env_var, default):
    try:
        if os.environ[env_var] == "true" :
            return True
        if os.environ[env_var] == "false" :
            return False
        return default
    except:
        return default

def environment_config():
    return FA2_config(
        debug_mode = global_parameter("debug_mode", False),
        single_asset = global_parameter("single_asset", False),
        non_fungible = global_parameter("non_fungible", False),
        readable = global_parameter("readable", True),
        force_layouts = global_parameter("force_layouts", True),
        assume_consecutive_token_ids =
            global_parameter("assume_consecutive_token_ids", True),
        lazy_entry_points = global_parameter("lazy_entry_points", False),
        lazy_entry_points_multiple = global_parameter("lazy_entry_points_multiple", False),
    )

## ## Standard “main”
##
## This specific main uses the relative new feature of non-default tests
## for the browser version.
if "templates" not in __name__:
    add_test(environment_config())
    # if not global_parameter("only_environment_test", False):
    #     add_test(FA2_config(debug_mode = True), is_default = not sp.in_browser)
    #     add_test(FA2_config(single_asset = True), is_default = not sp.in_browser)
    #              is_default = not sp.in_browser)
    #     add_test(FA2_config(readable = False), is_default = not sp.in_browser)
    #     add_test(FA2_config(force_layouts = False),
    #              is_default = not sp.in_browser)
    #     add_test(FA2_config(debug_mode = True, support_operator = False),
    #              is_default = not sp.in_browser)
    #     add_test(FA2_config(debug_mode = True, support_controller = False),
    #              is_default = not sp.in_browser)
    #     add_test(FA2_config(assume_consecutive_token_ids = False)
    #              , is_default = not sp.in_browser)
    #              , is_default = not sp.in_browser)
    #     add_test(FA2_config(lazy_entry_points = True)
    #              , is_default = not sp.in_browser)
    #     add_test(FA2_config(lazy_entry_points_multiple = True)
    #              , is_default = not sp.in_browser)

    sp.add_compilation_target(
        "ST2_compiled",
        ST2(
            config = environment_config(),
            metadata = sp.metadata_of_url("https://example.com"),
            administrators = sp.set([sp.address("tz1M9CMEtsXm3QxA7FmMU2Qh7xzsuGXVbcDr")])
        )
    )

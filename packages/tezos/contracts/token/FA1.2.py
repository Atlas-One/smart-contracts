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

def make_roles(administrators, validators, controllers, burners, minters):
    return sp.map(
        {
            ADMIN_ROLE: make_role(ADMIN_ROLE, administrators),
            CONTROLLER_ROLE: make_role(ADMIN_ROLE, controllers),
            MINTER_ROLE: make_role(ADMIN_ROLE, minters),
            BURNER_ROLE: make_role(ADMIN_ROLE, burners),
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
        # admin has all roles
        sp.verify(self.has_role(ADMIN_ROLE, params.account) | self.has_role(params.role, params.account))
    
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
    def set_paused(self, paused):
        sp.verify(self.sender_has_role(PAUSER_ROLE) | self.sender_has_role(ADMIN_ROLE))
        self.data.paused = paused

class Mintable(AccessControl):

    def is_minter(self):
        return (self.sender_has_role(MINTER_ROLE) | self.sender_has_role(ADMIN_ROLE))

    @sp.sub_entry_point
    def _mint(self, params):
        sp.set_type(params, 
            sp.TRecord(
                address=sp.TAddress,
                amount=sp.TNat
            )
        )
        
        # verify issuable
        sp.verify(self.data.issuable)
        
        self.add_address_if_necessary(params.address)

        self.data.ledger[params.address].balance += params.amount
        self.data.total_supply += params.amount

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
                amount=sp.TNat
            )
        )

        sp.verify(self.data.ledger[params.address].balance >= params.amount)

        self.decrease_and_remove_balance_if_necessary(params.address, params.amount)
        
        self.data.total_supply = sp.as_nat(self.data.total_supply - params.amount)

    # a.k.a redeem / redeemMultiple
    @sp.entry_point
    def burn(self, params):
        sp.verify(self.is_burner())

        sp.for p in params:
            self._burn(p)


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


class Operator(Controller):

    def is_operator(self, params):
        return (
            (params.owner == params.operator) | 
            (self.is_controller(params.operator)) |
            (self.data.operable & (
                (self.data.ledger.contains(params.owner) & 
                self.data.ledger[params.owner].operators.contains(params.operator)) | 
                (self.data.ledger.contains(params.owner) & 
                self.data.ledger[params.owner].approvals.contains(params.operator) & 
                (self.data.ledger[params.owner].approvals[params.operator] >= params.amount))
            ))
        )

    @sp.entry_point
    def update_operators(self, params):
        sp.set_type(
            params, 
            sp.TList(
                sp.TVariant(
                    add_operators = sp.TList(sp.TRecord(
                        owner = sp.TAddress,
                        operator = sp.TAddress
                    )),
                    remove_operators = sp.TList(sp.TRecord(
                        owner = sp.TAddress,
                        operator = sp.TAddress
                    ))
                )
            )
        )
        sp.if self.data.operable:
            sp.for update in params:
                with update.match_cases() as arg:
                    with arg.match("add_operators") as add_operators:
                        sp.for upd in add_operators:
                            sp.verify(
                                (upd.owner == sp.sender) |
                                (self.is_controller(sp.sender))
                            )
                            self.data.ledger[upd.owner].operators.add(upd.operator)
                    with arg.match("remove_operators") as remove_operators:
                        sp.for upd in remove_operators:
                            sp.verify(
                                (upd.owner == sp.sender) |
                                (self.is_controller(sp.sender))
                            )
                            self.data.ledger[upd.owner].operators.remove(upd.operator)
        sp.else:
            sp.failwith("noop")


class Ledger_key:
    
    def __init__(self, config):
        self.config = config

    def make(self, user):
        user = sp.set_type_expr(user, sp.TAddress)

        result = user

        if self.config.readable:
            return result
        else:
            return sp.pack(result)


class Ledger_value:
   
    def get_type():
        return sp.TRecord(
            balance=sp.TNat,
            operators=sp.TSet(
                sp.TAddress
            ),
            approvals=sp.TMap(
                sp.TAddress,
                sp.TNat,
            ),
        )

    def make(balance):
        return sp.record(
            balance=balance,
            operators=sp.set([], t=sp.TAddress),
            approvals=sp.map()
        )


class Ledger(sp.Contract):
    def __init__(self, debug_mode, **extra_storage):

        if debug_mode:
            self.ledger_map = sp.map
        else:
            self.ledger_map = sp.big_map

        self.init(
            total_supply=sp.as_nat(0),
            ledger=self.ledger_map(tvalue=Ledger_value.get_type()),
            **extra_storage
        )

    def decrease_approval_if_necessary(self, key, operator, amount):
        sp.if self.data.ledger.contains(key):
            sp.if self.data.ledger[key].approvals.contains(operator):
                sp.if self.data.ledger[key].approvals[operator] > amount:
                    self.data.ledger[key].approvals[operator] = sp.as_nat(self.data.ledger[key].approvals[operator] - amount)

    def decrease_and_remove_balance_if_necessary(self, key, amount):
        sp.if self.data.ledger.contains(key):
            self.data.ledger[key].balance = sp.as_nat(self.data.ledger[key].balance - amount)
            sp.if self.data.ledger[key].balance <= 0:
                del self.data.ledger[key]
    
    def add_address_if_necessary(self, address):
        sp.if ~self.data.ledger.contains(address):
            self.data.ledger[address] = Ledger_value.make(0)


class TransferValidation(Controller):

    def assertTransfer(self, params):
        sp.set_type(params, sp.TRecord(from_ = sp.TAddress, to_ = sp.TAddress))
        sp.for validator in self.data.roles[VALIDATOR_ROLE].members.elements():
            c = sp.contract(
                t = sp.TRecord(
                    from_=sp.TAddress,
                    to_=sp.TAddress,
                    operator=sp.TAddress,
                    is_controller=sp.TBool
                ), 
                address = validator, 
                entry_point = "assertTransfer"
            ).open_some()
                        
            sp.transfer(
                sp.record(
                    operator=sp.sender,
                    is_controller=self.is_controller(sp.sender),
                    from_=params.from_,
                    to_=params.to_
                ),
                sp.mutez(0),
                c
            )


class FA12_config:
    def __init__(
        self,
        debug_mode=False,
        readable=True,
        force_layouts=True,
        lazy_entry_points=False,
        lazy_entry_points_multiple=False,
    ):

        self.debug_mode = debug_mode
        # The option `debug_mode` makes the code generation use
        # regular maps instead of big-maps, hence it makes inspection
        # of the state of the contract easier.

        self.readable = readable
        # The `readable` option is a legacy setting that we keep around
        # only sp.for benchmarking purposes.
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

        self.lazy_entry_points = lazy_entry_points
        self.lazy_entry_points_multiple = lazy_entry_points_multiple
        #
        # Those are “compilation” options of SmartPy into Michelson.
        #
        if lazy_entry_points and lazy_entry_points_multiple:
            raise Exception("Cannot provide lazy_entry_points and lazy_entry_points_multiple")

        name = "FA12"
        if debug_mode:
            name += "-debug"
        if not readable:
            name += "-no_readable"
        if not force_layouts:
            name += "-no_layout"
        if lazy_entry_points:
            name += "-lep"
        if lazy_entry_points_multiple:
            name += "-lepm"
        self.name = name


class FA12_core(Ledger):
    def __init__(self, config, **extra_storage):
        self.config = config

        Ledger.__init__(
            self,
            debug_mode=self.config.debug_mode,
            **extra_storage
        )

    @sp.sub_entry_point
    def _transfer(self, params):
        sp.set_type(params, 
            sp.TRecord(
                from_ = sp.TAddress,
                to_ = sp.TAddress,
                value = sp.TNat
            ))

        # if paused only admin and controller can operate
        sp.if self.is_paused():
            sp.verify(self.is_controller(sp.sender))
        sp.else:
            sp.verify(
                self.is_operator(
                    sp.record(
                        owner=params.from_,
                        operator=sp.sender,
                        amount=params.value
                    )
                )
            )

        self.assertTransfer(sp.record(from_ = params.from_, to_ = params.to_))

        self.add_address_if_necessary(params.to_)

        sp.verify(self.data.ledger[params.from_].balance >= params.value)
        
        self.data.ledger[params.to_].balance += params.value
        self.decrease_and_remove_balance_if_necessary(params.from_, params.value)
        
        self.decrease_approval_if_necessary(params.from_, sp.sender, params.value)
    
    # (address :from, (address :to, nat :value))    %transfer
    @sp.entry_point
    def transfer(self, params):
        sp.set_type(params,
            sp.TRecord(
                from_ = sp.TAddress,
                to_ = sp.TAddress,
                value = sp.TNat
            ).layout(
                ("from_ as from", ("to_ as to", "value"))
            )
        )
        
        self._transfer(
            sp.record(
                from_ = params.from_,
                to_ = params.to_,
                value = params.value
            )
        )

    @sp.entry_point
    def transferMultiple(self, params):
        sp.for p in params:
            self._transfer(p)

    # (address :spender, nat :value)                %approve
    @sp.entry_point
    def approve(self, params):
        sp.set_type(
            params,
            sp.TRecord(
                spender = sp.TAddress,
                value = sp.TNat
            ).layout(("spender", "value"))
        )
        
        sp.verify(~self.is_paused())

        # Allow changing approve value to any value
        # alreadyApproved = self.data.ledger[sp.sender].approvals.get(params.spender, 0)
        # sp.verify((alreadyApproved == 0) | (params.value == 0), "UnsafeAllowanceChange")
        
        self.data.ledger[sp.sender].approvals[params.spender] = params.value
    
    # (view (address :owner) nat)                   %getBalance
    @sp.utils.view(sp.TNat)
    def getBalance(self, params):
        sp.set_type(params, sp.TAddress)
        
        sp.result(self.data.ledger[params].balance)
    
    # (view (address :owner, address :spender) nat) %getAllowance
    @sp.utils.view(sp.TNat)
    def getAllowance(self, params):
        sp.set_type(
            params,
            sp.TRecord(
                owner = sp.TAddress,
                spender = sp.TAddress
            ).layout(("owner", "spender"))
        )
        
        sp.verify(self.data.operable)
        
        sp.result(self.data.ledger[params.owner].approvals[params.spender])
    
    # (view unit nat)                               %getTotalSupply
    @sp.utils.view(sp.TNat)
    def getTotalSupply(self, params):
        sp.set_type(params, sp.TUnit)
        sp.result(self.data.total_supply)


class ST12(
    Operator,
    Pausable,
    Mintable,
    Burnable,
    TransferValidation,
    FA12_core
):
    def __init__(
            self,
            config,
            contract_metadata,
            token_metadata,
            administrators,
            validators=sp.set([], t=sp.TAddress),
            controllers=sp.set([], t=sp.TAddress),
            burners=sp.set([], t=sp.TAddress),
            minters=sp.set([], t=sp.TAddress)
        ):
            
        FA12_core.__init__(
            self,
            config,
            paused=False,
            operable=True,
            issuable=True,
            controllable=True,
            # Contract metadata
            metadata=contract_metadata,
            # Token specific metadata
            token_metadata=token_metadata,
            roles=make_roles(
                administrators=administrators, 
                validators=validators,
                controllers=controllers,
                burners=burners,
                minters=burners,
            )
        )
    
    @sp.entry_point
    def set_metadata(self, k, v):
        sp.verify(self.sender_has_role(ADMIN_ROLE))
        self.data.metadata[k] = v


# ## Generation of Test Scenarios
def add_test(config, is_default=True):
    @sp.add_test(name=config.name, is_default=is_default)
    def test():
        scenario = sp.test_scenario()
        scenario.h1("Simple ST12 Contract")

        # sp.test_account generates ED25519 key-pairs deterministically:
        admin = sp.test_account("AccessControl")
        alice = sp.test_account("Alice")
        bob = sp.test_account("Robert")

        # Let's display the accounts:
        scenario.h2("Accounts")
        scenario.show([admin, alice, bob])

        c1 = ST12(
            config = config,
            administrators = sp.set([admin.address]),
            contract_metadata = sp.big_map(l = {
                "": sp.utils.bytes_of_string("tezos-storage:m"),
                "m" : sp.utils.bytes_of_string("{\"name\":\"Test\",\"version\":\"security token v1.0\",\"description\":\"Test Digital Security Token\"}"),
            }),
            token_metadata = sp.big_map(l = {
                sp.nat(0): sp.record(
                    token_id = sp.nat(0),
                    token_info = sp.map(l = {
                        "decimals" : sp.utils.bytes_of_string("18"),
                        "name" : sp.utils.bytes_of_string("Test"),
                        "symbol" : sp.utils.bytes_of_string("TST"),
                    })
                )
            })
        )

        scenario += c1
            
        scenario.h2("Admin mints a few coins")
        scenario += c1.mint(sp.list([sp.record(address=alice.address, amount=12)])).run(sender=admin)
        scenario += c1.mint(sp.list([
            sp.record(address=alice.address, amount=3),
            sp.record(address=alice.address, amount=3),
            ])).run(sender=admin)
        scenario.h2("Alice transfers her own tokens to Bob")
        scenario += c1.transfer(from_=alice.address, to_=bob.address, value=4).run(
            sender=alice
        )
        scenario.verify(c1.data.ledger[alice.address].balance == 14)
        scenario.h2("Bob tries to transfer from Alice but he doesn't have her approval")
        scenario += c1.transfer(from_=alice.address, to_=bob.address, value=4).run(
            sender=bob, valid=False
        )
        scenario.h2("Alice approves Bob and Bob transfers")
        scenario += c1.approve(spender=alice.address, value=5).run(
            sender=alice
        )
        scenario += c1.transfer(from_=alice.address, to_=bob.address, value=4).run(
            sender=admin
        )
        scenario.h2("Bob tries to over-transfer from Alice")
        scenario += c1.transfer(from_=alice.address, to_=bob.address, value=4).run(
            sender=bob, valid=False
        )
        scenario.h2("Admin burns Bob token")
        scenario += c1.burn(sp.list([sp.record(address=bob.address, amount=1)])).run(sender=admin)
        scenario.verify(c1.data.ledger[alice.address].balance == 10)
        scenario.h2("Alice tries to burn Bob token")
        scenario += c1.burn(sp.list([sp.record(address=bob.address, amount=1)])).run(
            sender=alice, valid=False
        )
        scenario.h2("Admin pauses the contract and Alice cannot transfer anymore")
        scenario += c1.set_paused(True).run(sender=admin)
        scenario += c1.transfer(from_=alice.address, to_=bob.address, value=4).run(
            sender=alice, valid=False
        )
        scenario.verify(c1.data.ledger[alice.address].balance == 10)
        scenario.h2("Admin transfers while on pause")
        scenario += c1.transfer(from_=alice.address, to_=bob.address, value=1).run(
            sender=admin
        )
        scenario.h2("Admin unpauses the contract and transferts are allowed")
        scenario += c1.set_paused(False).run(sender=admin)
        scenario.verify(c1.data.ledger[alice.address].balance == 9)
        scenario += c1.transfer(from_=alice.address, to_=bob.address, value=1).run(
            sender=admin
        )

        scenario.verify(c1.data.total_supply == 17)
        scenario.verify(c1.data.ledger[alice.address].balance == 8)
        scenario.verify(c1.data.ledger[bob.address].balance == 9)
        
        scenario.h2("Burn")
        scenario += c1.burn(
            sp.list([
                sp.record(
                address=alice.address,
                amount=3
            )
            ])
        ).run(sender=admin)
        
        scenario += c1.burn(
            sp.list(
                [
                    sp.record(
                        address=alice.address,
                        amount=3
                    )
                ]
            )
        ).run(sender=admin)

        scenario.table_of_contents()

#
# # Global Environment Parameters
#
# The build system communicates with the python script through
# environment variables.
def global_parameter(env_var, default):
    try:
        if os.environ[env_var] == "true":
            return True
        if os.environ[env_var] == "false":
            return False
        return default
    except:
        return default


def environment_config():
    return FA12_config(
        debug_mode=global_parameter("debug_mode", False),
        readable=global_parameter("readable", True),
        force_layouts=global_parameter("force_layouts", True),
        lazy_entry_points=global_parameter("lazy_entry_points", False),
        lazy_entry_points_multiple=global_parameter(
            "lazy_entry_points_multiple", False
        ),
    )


# # Standard “main”
#
# This specific main uses the relative new feature of non-default tests
# sp.for the browser version.
if "templates" not in __name__:
    add_test(environment_config())

    sp.add_compilation_target(
        "ST12_compiled", 
        ST12(
            config = environment_config(),
            contract_metadata = sp.big_map(l = {
                "": sp.utils.bytes_of_string("tezos-storage:m"),
                "m" : sp.utils.bytes_of_string("{\"name\":\"Test\",\"version\":\"security token v1.0\",\"description\":\"Test Digital Security Token\"}"),
            }),
            token_metadata = sp.big_map(l = {
                sp.nat(0): sp.record(
                    token_id = sp.nat(0),
                    token_info = sp.map(l = {
                        "decimals" : sp.utils.bytes_of_string("18"),
                        "name" : sp.utils.bytes_of_string("Test"),
                        "symbol" : sp.utils.bytes_of_string("TST"),
                    })
                )
            }),
            administrators = sp.set([sp.address("tz1M9CMEtsXm3QxA7FmMU2Qh7xzsuGXVbcDr")]),
            validators = sp.set([sp.address("KT1QkFxZqfCok6LZUJ7zDn6gCDBS7kSao26P")]),
            burners = sp.set([sp.address("KT1S3M3Cn7XBLcNi54cfvMP15j9ew4W4eb1C")]),
            minters = sp.set([sp.address("KT1S3M3Cn7XBLcNi54cfvMP15j9ew4W4eb1C")]),
        )
    )

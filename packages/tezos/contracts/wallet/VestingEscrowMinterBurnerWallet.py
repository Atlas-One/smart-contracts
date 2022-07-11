# Vesting Escrow Wallet
# - Vests multiple tokens
# - Supports FA2 and FA1.2
# - Mints tokens to itself for lock up when vest(...) is

import smartpy as sp


TOKEN_ADMIN_ROLE = 0

def assert_token_admin(token, account):
    c = sp.contract(
        t = sp.TRecord(
            account=sp.TAddress,
            role=sp.TNat
        ), 
        address = token, 
        entry_point = "assertRole"
    ).open_some()
    
    sp.transfer(
        sp.record(
            role=TOKEN_ADMIN_ROLE,
            account=account
        ),
        sp.mutez(0),
        c
    )

class VestingEscrowMinterBurnerWallet(sp.Contract):
    def __init__(self):
        self.init(
            schedules = sp.map(
                tkey= sp.TAddress, 
                tvalue= sp.TMap(
                    sp.TString,
                    sp.TRecord(
                        revoked = sp.TBool,
                        revokedAt = sp.TOption(sp.TTimestamp),
                        revokedBy = sp.TOption(sp.TAddress),
                        start = sp.TTimestamp,
                        end = sp.TTimestamp,
                        cliff = sp.TTimestamp,
                        vesting_amount = sp.TNat,
                        claimed_amount = sp.TNat,
                        token_address = sp.TAddress,
                        token_id = sp.TOption(sp.TNat)
                    )
                )
            )
        )
    
    @sp.sub_entry_point
    def _vest(self, params):
        sp.set_type(params,
            sp.TRecord(
                schedule_name = sp.TString,
                beneficiery = sp.TAddress,
                start = sp.TTimestamp,
                end = sp.TTimestamp,
                cliff = sp.TTimestamp,
                vesting_amount = sp.TNat,
                token_address = sp.TAddress,
                token_id = sp.TOption(sp.TNat),
                metadata=sp.TOption(sp.TMap(sp.TString, sp.TBytes))
            )
        )
        
        # if you send the same schedule_name
        # it will add to the vesting amount
        schedule_name = params.schedule_name
        
        sp.verify(params.start < params.cliff)
        sp.verify(params.start < params.end)
        sp.verify(params.cliff < params.end)
        
        beneficiery = params.beneficiery
        
        schedule = sp.record(
            revoked = False,
            revokedAt = sp.none,
            revokedBy = sp.none,
            start = params.start,
            end = params.end,
            cliff = params.cliff,
            claimed_amount = sp.as_nat(0),
            token_id = params.token_id,
            token_address = params.token_address,
            vesting_amount = params.vesting_amount,
        )
        
        sp.if ~self.data.schedules.contains(beneficiery):
            self.data.schedules[beneficiery] = {}
            self.data.schedules[beneficiery][schedule_name] = schedule
        sp.else:
            sp.if ~self.data.schedules[beneficiery].contains(schedule_name):
                self.data.schedules[beneficiery][schedule_name] = schedule
            sp.else:
                self.data.schedules[beneficiery][schedule_name].vesting_amount += params.vesting_amount
   
    @sp.entry_point
    def vest(self, params):
        sp.set_type(
            params, 
            sp.TList(
                sp.TRecord(
                    schedule_name = sp.TString,
                    beneficiery = sp.TAddress,
                    start = sp.TTimestamp,
                    end = sp.TTimestamp,
                    cliff = sp.TTimestamp,
                    vesting_amount = sp.TNat,
                    token_address = sp.TAddress,
                    token_id = sp.TOption(sp.TNat),
                    metadata=sp.TOption(sp.TMap(sp.TString, sp.TBytes))
                )
            )
        )

        sp.for schedule in params:
            self._vest(schedule)
            self._mint(
                sp.record(
                    to_ = sp.self_address,
                    amount = schedule.vesting_amount,
                    token_id = schedule.token_id,
                    token_address = schedule.token_address,
                    metadata = schedule.metadata
                )
            )

    @sp.sub_entry_point
    def _vested(self, params):
        vested_amount = sp.local('vested_amount', sp.as_nat(0))
        
        sp.verify(self.data.schedules.contains(params.beneficiery) & 
            self.data.schedules[params.beneficiery].contains(params.schedule_name))
            
        schedule = self.data.schedules[params.beneficiery][params.schedule_name]
            
        sp.verify(schedule.claimed_amount < schedule.vesting_amount)
        
        sp.if schedule.revoked:
            vested_amount.value = sp.as_nat(0)
        sp.else:    
            sp.if ((schedule.start > sp.now) | (schedule.cliff > sp.now)):
                vested_amount.value = sp.as_nat(0)
            sp.else:
                sp.if sp.now >= schedule.end:
                    vested_amount.value = schedule.vesting_amount
                sp.else:
                    sp.if ((sp.now >= schedule.cliff) & (sp.now < schedule.end)):
                        vested_amount.value = schedule.vesting_amount * sp.as_nat(sp.now - schedule.start) / sp.as_nat(schedule.end - schedule.start)
            
        sp.result(vested_amount.value)
        
    @sp.entry_point
    def vestedAmount(self, params):
        vested_amount = self._vested(sp.record(
                beneficiery= params.beneficiery, schedule_name= params.schedule_name))
        
        sp.transfer(
            vested_amount, 
            sp.tez(0), sp.contract(sp.TNat, params.target).open_some())

    @sp.entry_point
    def claimableAmount(self, params):
        vested_amount = self._vested(
            sp.record(
                beneficiery = params.beneficiery,
                schedule_name = params.schedule_name
            )
        )
        
        schedule = self.data.schedules[params.beneficiery][params.schedule_name]
        
        sp.transfer(
            sp.as_nat(vested_amount - schedule.claimed_amount), 
            sp.tez(0), sp.contract(sp.TNat, params.target).open_some())
    
    @sp.sub_entry_point
    def _mint(self, params):
        sp.set_type(params, 
            sp.TRecord(
                to_ = sp.TAddress,
                amount = sp.TNat,
                token_address = sp.TAddress,
                token_id = sp.TOption(sp.TNat),
                metadata=sp.TOption(sp.TMap(sp.TString, sp.TBytes))
            )
        )
        
        sp.if params.token_id.is_some():
            c = sp.contract(
                t = sp.TRecord(
                        address = sp.TAddress,
                        amount = sp.TNat,
                        token_id=sp.TNat,
                        metadata=sp.TMap(sp.TString, sp.TBytes)
                    ), 
                    address = params.token_address, 
                    entry_point = "mint"
                ).open_some()
                            
            sp.transfer(
                sp.record(
                    address = params.to_,
                    amount = params.amount,
                    token_id = params.token_id.open_some(),
                    metadata = params.metadata.open_some()
                ), 
                sp.mutez(0),
                c
            )
        sp.else:
            c = sp.contract(
                t = sp.TRecord(
                        address = sp.TAddress,
                        amount = sp.TNat
                    ), 
                    address = params.token_address, 
                    entry_point = "mint"
                ).open_some()
                            
            sp.transfer(
                sp.record(
                    address = params.to_,
                    amount = params.amount
                ), 
                sp.mutez(0),
                c
            )
    
    @sp.sub_entry_point
    def _transfer(self, params):
        sp.set_type(params, 
            sp.TRecord(
                token_id = sp.TOption(sp.TNat),
                token_address = sp.TAddress,
                from_ = sp.TAddress, 
                to_ = sp.TAddress,
                amount = sp.TNat
            )
        )
        sp.if params.token_id.is_some():
            c = sp.contract(
                t = sp.TRecord(
                    token_id = sp.TNat,
                    from_ = sp.TAddress, 
                    to_ = sp.TAddress,
                    amount = sp.TNat
                ), 
                address = params.token_address,
                entry_point = "transfer"
            ).open_some()
                
            sp.transfer(
                sp.record(
                    token_id = params.token_id.open_some(),
                    from_ = params.from_,
                    to_ = params.to_,
                    amount = params.amount
                ), 
                sp.mutez(0),
                c
            )
        sp.else:
            c = sp.contract(
                t = sp.TRecord(
                    from_ = sp.TAddress, 
                    to_ = sp.TAddress,
                    value = sp.TNat
                ), 
                address = params.token_address,
                entry_point = "transfer"
            ).open_some()
                            
            sp.transfer(
                sp.record(
                    from_ = params.from_,
                    to_ = params.to_,
                    value = params.amount
                ), 
                sp.mutez(0),
                c
            )
    
    @sp.entry_point
    def claimFor(self, beneficiery):
        sp.verify(self.data.schedules.contains(beneficiery))
        
        sp.for schedule_name in self.data.schedules[beneficiery].keys():
            schedule = self.data.schedules[beneficiery][schedule_name]
            
            vested_amount = self._vested(
                sp.record(
                    beneficiery= beneficiery,
                    schedule_name= schedule_name
                )
            )
            
            claim_amount = sp.local('claim_amount', sp.as_nat(0))
            
            claim_amount.value = sp.as_nat(vested_amount - schedule.claimed_amount)
            schedule.claimed_amount += claim_amount.value
            
            self._transfer(
                sp.record(
                    from_ = sp.self_address,
                    to_ = beneficiery,
                    amount = claim_amount.value,
                    token_id = schedule.token_id,
                    token_address = schedule.token_address
                )
            )
    
    @sp.entry_point
    def claim(self):
        sp.verify(self.data.schedules.contains(sp.sender))
        
        sp.for schedule_name in self.data.schedules[sp.sender].keys():
            schedule = self.data.schedules[sp.sender][schedule_name]
            
            vested_amount = self._vested(
                sp.record(
                    beneficiery= sp.sender,
                    schedule_name= schedule_name
                )
            )
            
            claim_amount = sp.local('claim_amount', sp.as_nat(0))
            
            claim_amount.value = sp.as_nat(vested_amount - schedule.claimed_amount)
            schedule.claimed_amount += claim_amount.value
            
            self._transfer(
                sp.record(
                    from_ = sp.self_address,
                    to_ = sp.sender,
                    amount = claim_amount.value,
                    token_id = schedule.token_id,
                    token_address = schedule.token_address
                )
            )
        
    @sp.entry_point
    def revokeSchedule(self, params):
        sp.for p in params:
            schedule = self.data.schedules[p.beneficiery][p.schedule_name]
                
            assert_token_admin(schedule.token_address, sp.sender)
            
            schedule.revoked = True
            schedule.revokedAt = sp.some(sp.now)
            schedule.revokedBy = sp.some(sp.sender)
        
    @sp.entry_point
    def revokeSchedules(self, beneficieries):
        sp.for beneficiery in beneficieries:
            sp.for schedule_name in self.data.schedules[beneficiery].keys():
                schedule = self.data.schedules[beneficiery][schedule_name]
                
                assert_token_admin(schedule.token_address, sp.sender)
                
                schedule.revoked = True
                schedule.revokedAt = sp.some(sp.now)
                schedule.revokedBy = sp.some(sp.sender)
        
    @sp.entry_point
    def changeBeneficiery(self, params):
        sp.for p in params:
            assert_token_admin(self.data.schedules[p.from_][p.schedule_name].token_address, sp.sender)
            
            sp.if ~self.data.schedules.contains(p.to_):
                self.data.schedules[p.to_] = {}
            self.data.schedules[p.to_][p.schedule_name] = self.data.schedules[p.from_][p.schedule_name]
            del self.data.schedules[p.from_][p.schedule_name]

    @sp.entry_point
    def changeBeneficieryForAll(self, params):
        sp.for p in params:
            sp.for schedule_name in self.data.schedules[p.from_].keys():
                assert_token_admin(self.data.schedules[p.from_][schedule_name].token_address, sp.sender)
                
            self.data.schedules[p.to_] = self.data.schedules[p.from_]
            del self.data.schedules[p.from_]


# Test Security Token FA1.2 Compliant
class ST12(sp.Contract):
    
    def __init__(self, admin):
        self.init(admin=admin)
    
    @sp.entry_point
    def assertRole(self, params):
        sp.set_type(params, sp.TRecord(account=sp.TAddress, role=sp.TNat))
        sp.verify(self.data.admin == params.account)
    
    @sp.entry_point
    def mint(self, params):
        sp.set_type(params, sp.TRecord(address=sp.TAddress, amount=sp.TNat))
    
    @sp.entry_point
    def transfer(self, params):
        sp.set_type(params, sp.TRecord(from_=sp.TAddress, to_=sp.TAddress, value=sp.TNat))


# Test Security Token FA2 Compliant
class ST2(sp.Contract):
    
    def __init__(self, admin):
        self.init(admin=admin)
    
    @sp.entry_point
    def assertRole(self, params):
        sp.set_type(params, sp.TRecord(account=sp.TAddress, role=sp.TNat))
        sp.verify(self.data.admin == params.account)
    
    @sp.entry_point
    def mint(self, params):
        sp.set_type(params, 
            sp.TRecord(
                address=sp.TAddress,
                amount=sp.TNat,
                token_id=sp.TNat,
                metadata=sp.TMap(sp.TString, sp.TBytes),
            )
        )
    
    @sp.entry_point
    def transfer(self, params):
        sp.set_type(
            params, 
            sp.TRecord(
                token_id = sp.TNat,
                from_ = sp.TAddress,
                to_ = sp.TAddress,
                amount = sp.TNat
            )
        )


def add_test(is_default=True):
    @sp.add_test(name = "VestingEscrowMinterBurnerWallet", is_default=is_default)
    def test():
        scenario = sp.test_scenario()
        
        scenario.h1("VestingEscrowMinterBurnerWallet")
        
        admin = sp.test_account("Token Admin")
        alice = sp.test_account("Alice")
        bob = sp.test_account("Bob")
        
        fa12 = ST12(admin.address)
        fa2 = ST2(admin.address)
        v = VestingEscrowMinterBurnerWallet()
        
        scenario += fa12
        scenario += fa2
        scenario += v
        scenario += v.vest(
            sp.list([
                sp.record(
                    schedule_name = "4 Months Cliff Vesting From 12-12-2020",
                    beneficiery = alice.address, 
                    start = sp.timestamp(0), 
                    cliff = sp.timestamp(5), 
                    end = sp.timestamp(10), 
                    vesting_amount = 100,
                    token_address = fa2.address,
                    token_id = sp.some(0),
                    metadata = sp.some(sp.map({
                        "decimals": sp.utils.bytes_of_string("%d" % 18),
                        "name": sp.utils.bytes_of_string("Test"),
                        "symbol": sp.utils.bytes_of_string("TEST")
                    }))
                )
            ])
        )
        
        scenario += v.claim().run(sender = alice, now = sp.timestamp(5))
        scenario += v.claim().run(sender = alice, now = sp.timestamp(7))
        scenario += v.claim().run(sender = alice, now = sp.timestamp(10))
        scenario += v.claim().run(sender = alice, now = sp.timestamp(10), valid=False)
        scenario += v.claim().run(sender = alice, now = sp.timestamp(15), valid=False)
        
        scenario += v.vest(
            sp.list([
                sp.record(
                    schedule_name = "5 Months Cliff Vesting From 12-12-2020",
                    beneficiery = alice.address, 
                    start = sp.timestamp(0), 
                    cliff = sp.timestamp(5), 
                    end = sp.timestamp(10), 
                    vesting_amount = 200,
                    token_address = fa12.address,
                    token_id = sp.none,
                    metadata = sp.none
                ),
                sp.record(
                    schedule_name = "8 Months Cliff Vesting From 12-12-2020",
                    beneficiery = bob.address, 
                    start = sp.timestamp(0), 
                    cliff = sp.timestamp(5), 
                    end = sp.timestamp(10), 
                    vesting_amount = 200,
                    token_address = fa12.address,
                    token_id = sp.none,
                    metadata = sp.none
                )
            ])
        )
        
        scenario += v.changeBeneficiery(
            sp.list([
                sp.record(
                    schedule_name = "8 Months Cliff Vesting From 12-12-2020",
                    from_ = bob.address, 
                    to_ = alice.address
                )
            ])
        ).run(sender = alice, valid = False)
        
        scenario += v.changeBeneficiery(
            sp.list([
                sp.record(
                    schedule_name = "8 Months Cliff Vesting From 12-12-2020",
                    from_ = bob.address, 
                    to_ = alice.address
                )
            ])
        ).run(sender = admin)
        
        scenario += v.changeBeneficieryForAll(
            sp.list([
                sp.record(
                    from_ = alice.address, 
                    to_ = bob.address
                )
            ])
        ).run(sender = alice, valid = False)
        
        scenario += v.changeBeneficieryForAll(
            sp.list([
                sp.record(
                    from_ = alice.address, 
                    to_ = bob.address
                )
            ])
        ).run(sender = admin)


if "templates" not in __name__:
    add_test()
    sp.add_compilation_target("VestingEscrowMinterBurnerWallet_compiled", VestingEscrowMinterBurnerWallet())

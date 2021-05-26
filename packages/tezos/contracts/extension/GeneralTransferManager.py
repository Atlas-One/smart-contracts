##
## ## General Transfer Manager - Using only assertTransfer from TZIP-15
##
## See the TZIP-15 standard definition:
## <https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-15/>
##
##

import smartpy as sp


ADMIN_ROLE = 0
ALLOWLIST_ADMIN_ROLE = 1
BLOCKLIST_ADMIN_ROLE = 2

TOKEN_CONTROLLER_ROLE = 1

def make_role(role_admin, members=sp.set([], t=sp.TAddress)):
    return sp.record(
        role_admin = role_admin,
        members = members
    )


def make_roles(administrators=sp.set([], t=sp.TAddress), validators=sp.set([], t=sp.TAddress), controllers=sp.set([], t=sp.TAddress)):
    return sp.map(
        {
            ADMIN_ROLE: make_role(ADMIN_ROLE, administrators),
            ALLOWLIST_ADMIN_ROLE: make_role(ADMIN_ROLE, controllers),
            BLOCKLIST_ADMIN_ROLE: make_role(ADMIN_ROLE)
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
    

class GeneralTransferManager(AccessControl):
    
    def __init__(self, administrators):
        self.init(
            allowlist = sp.set([], t=sp.TAddress),
            blocklist = sp.set([], t=sp.TAddress),
            roles = make_roles(administrators=administrators)
        )

    @sp.entry_point
    def addToAllowlist(self, params):
        sp.verify(self.has_role(ALLOWLIST_ADMIN_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))
        sp.verify(~self.data.blocklist.contains(params.address))

        self.data.allowlist.add(params.address)
    
    @sp.entry_point
    def removeFromAllowlist(self, params):
        sp.verify(self.has_role(ALLOWLIST_ADMIN_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))

        self.data.allowlist.remove(params.address)
     
    @sp.entry_point
    def addToBlocklist(self, params):
        sp.verify(self.has_role(BLOCKLIST_ADMIN_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))

        sp.if self.data.allowlist.contains(params.address):
            self.data.allowlist.remove(params.address)

        self.data.blocklist.add(params.address)
    
    @sp.entry_point
    def removeFromBlocklist(self, params):
        sp.verify(self.has_role(BLOCKLIST_ADMIN_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))

        self.data.blocklist.remove(params.address)
    
    @sp.entry_point
    def assertTransfer(self, params):
        sp.set_type(
            params, 
            sp.TRecord(
                from_=sp.TAddress,
                to_=sp.TAddress,
                # we can assert the role of this operator
                operator=sp.TAddress
            )
        )

        sp.if ~self.data.allowlist.contains(params.from_) | self.data.blocklist.contains(params.from_):
            # controller should be able to move tokens out of a blocked address
            c = sp.contract(
                t = sp.TRecord(
                    role=sp.TNat,
                    account=sp.TAddress
                ), 
                address = sp.sender, 
                entry_point = "assertRole"
            ).open_some()
                        
            sp.transfer(
                sp.record(
                    role=TOKEN_CONTROLLER_ROLE,
                    account=params.operator
                ),
                sp.mutez(0),
                c
            )
        sp.verify(self.data.allowlist.contains(params.to_))
        sp.verify(~self.data.blocklist.contains(params.to_))


class TestToken(sp.Contract):
    def __init__(self, gtm, controller):
        self.init(gtm=gtm, controller=controller)
    
    @sp.entry_point
    def assertRole(self, params):
        sp.verify((sp.nat(TOKEN_CONTROLLER_ROLE) == params.role) & (params.account == self.data.controller))
    
    @sp.entry_point
    def transfer(self, params):
        # controller should be able to move tokens out of a blocked address
        c = sp.contract(
            t = sp.TRecord(
                from_=sp.TAddress,
                to_=sp.TAddress,
                operator=sp.TAddress
            ), 
            address = self.data.gtm, 
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
        

if "templates" not in __name__:
    @sp.add_test(name="GeneralTransferManager", is_default=True)
    def test():
        scenario = sp.test_scenario()
        scenario.h1("Simple ST12 Contract")

        # sp.test_account generates ED25519 key-pairs deterministically:
        admin = sp.test_account("Administrable")
        alice = sp.test_account("Alice")
        bob = sp.test_account("Robert")

        # Let's display the accounts:
        scenario.h2("Accounts")
        scenario.show([admin, alice, bob])
        
        g = GeneralTransferManager(sp.set([admin.address]))
        scenario += g
        
        t = TestToken(gtm=g.address, controller=admin.address)
        scenario += t
        
        scenario.h2("Not Controller Transfer")
        
        scenario.h3("Allowlisted from_ and to_")
        scenario += g.addToAllowlist(sp.record(address=alice.address)).run(sender=admin.address)
        scenario += g.addToAllowlist(sp.record(address=bob.address)).run(sender=admin.address)
        scenario += t.transfer(sp.record(to_=alice.address, from_=bob.address)).run(sender=bob.address)
        scenario.h3("Controller can move tokens")
        scenario += t.transfer(sp.record(to_=alice.address, from_=bob.address)).run(sender=admin.address)
        
        scenario.h3("Blocklisted to_")
        scenario += g.addToBlocklist(sp.record(address=alice.address)).run(sender=admin.address)
        scenario += t.transfer(sp.record(to_=alice.address, from_=bob.address)).run(sender=bob.address, valid=False)
        scenario.h3("Controller can't move tokens to a blocked address")
        scenario += t.transfer(sp.record(to_=alice.address, from_=bob.address)).run(sender=admin.address, valid=False)
        
        scenario.h3("Blocklisted from_")
        scenario += t.transfer(sp.record(to_=bob.address, from_=alice.address)).run(sender=alice.address, valid=False)
        scenario.h3("Controller can move tokens out of a blocked address")
        scenario += t.transfer(sp.record(to_=bob.address, from_=alice.address)).run(sender=admin.address)
        
        scenario.h3("Blocklisted to_")
        scenario += g.addToBlocklist(sp.record(address=bob.address)).run(sender=admin.address)
        scenario += t.transfer(sp.record(to_=alice.address, from_=bob.address)).run(sender=bob.address, valid=False)
        scenario.h3("Controller should not move tokens to a blocked address")
        scenario += t.transfer(sp.record(to_=alice.address, from_=bob.address)).run(sender=admin.address, valid=False)

    sp.add_compilation_target(
        "GeneralTransferManager_compiled", 
        GeneralTransferManager(
            administrators = sp.set([sp.address("tz1f6KNARa6KykKhoxAugtKwohmEfz8jrvUH")])
        )
    )

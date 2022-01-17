
import smartpy as sp


ADMIN_ROLE = 0
IDENTITY_MANAGER_ROLE = 1

def make_role(role_admin, members=sp.set([], t=sp.TAddress)):
    return sp.record(
        role_admin = role_admin,
        members = members
    )


def make_roles(administrators=sp.set([], t=sp.TAddress)):
    return sp.map(
        {
            ADMIN_ROLE: make_role(ADMIN_ROLE, administrators),
            IDENTITY_MANAGER_ROLE: make_role(ADMIN_ROLE),
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
    

class Identity(AccessControl):
    
    def __init__(self, administrators):
        self.init(
            identity_claims = sp.big_map(l={}, t=sp.TMap(sp.TString, sp.TSet(sp.TString))),
            identity_accounts = sp.big_map(l={}, t=sp.TMap(sp.TString, sp.TSet(sp.TAddress))),
            account_identity =  sp.big_map(l={}, t=sp.TSet(sp.TAddress)),
            roles = make_roles(administrators=administrators)
        )

    @sp.entry_point
    def addAccount(self, params):
        sp.verify(self.has_role(IDENTITY_MANAGER_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))
        sp.verify(~self.account_identity.contains(params.account))

        self.data.account_identity[params.account] = params.id

    @sp.entry_point
    def removeAccount(self, params):
        sp.verify(self.has_role(IDENTITY_MANAGER_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))

        self.data.account_identity.remove(params.account)

    @sp.entry_point
    def addClaim(self, params):
        sp.verify(self.has_role(IDENTITY_MANAGER_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))

        sp.verify(self.has_role(ADMIN_ROLE, sp.sender))

    @sp.entry_point
    def removeClaim(self, params):
        sp.verify(self.has_role(IDENTITY_MANAGER_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))
    
    @sp.entry_point
    def assertValid(self, params):
        sp.verify(self.data.account_identity.contains(params.account))
        sp.verify(self.data.identity_claims[self.data.account_identity[params.account]].contains(params.claim))


class TestToken(sp.Contract):
    def __init__(self, registery):
        self.init(registery=registery)
    
    @sp.entry_point
    def transfer(self, params):
        # controller should be able to move tokens out of a blocked address
        c = sp.contract(
            t = sp.TRecord(
                account=sp.TAddress,
                claim=sp.TString
            ), 
            address = self.data.registery, 
            entry_point = "assertValid"
        ).open_some()
                    
        sp.transfer(
            sp.record(
                account=params.from_,
                claim="Accredited"
            ),
            sp.mutez(0),
            c
        )
                    
        sp.transfer(
            sp.record(
                account=params.to_,
                claim="Accredited"
            ),
            sp.mutez(0),
            c
        )
        

if "templates" not in __name__:
    @sp.add_test(name="Identity", is_default=True)
    def test():
        pass

    sp.add_compilation_target(
        "Identity_compiled", 
        Identity(
            administrators = sp.set([sp.address("tz1f6KNARa6KykKhoxAugtKwohmEfz8jrvUH")])
        )
    )

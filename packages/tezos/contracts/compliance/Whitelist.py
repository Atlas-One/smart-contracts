
import smartpy as sp


ADMIN_ROLE = 0
WHITELIST_ADMIN_ROLE = 1
BLACKLIST_ADMIN_ROLE = 2

def make_role(role_admin, members=sp.set([], t=sp.TAddress)):
    return sp.record(
        role_admin = role_admin,
        members = members
    )


def make_roles(administrators=sp.set([], t=sp.TAddress)):
    return sp.map(
        {
            ADMIN_ROLE: make_role(ADMIN_ROLE, administrators),
            WHITELIST_ADMIN_ROLE: make_role(ADMIN_ROLE),
            BLACKLIST_ADMIN_ROLE: make_role(ADMIN_ROLE)
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
    

class Whitelist(AccessControl):
    
    def __init__(self, administrators):
        self.init(
            token_whitelist = sp.map(
                {},
                tkey=sp.TAddress,
                tvalue=sp.TSet(
                    t=sp.TAddress
                )
            ),
            blacklist = sp.set([],t=sp.TAddress),
            roles = make_roles(administrators=administrators)
        )

    @sp.entry_point
    def addToWhitelist(self, params):
        sp.verify(self.has_role(WHITELIST_ADMIN_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))
        sp.verify(~self.data.blacklist.contains(params.account))

        sp.if ~self.data.token_whitelist.contains(params.token):
            self.data.token_whitelist[params.token] = sp.set([])
        
        self.data.token_whitelist[params.token].add(params.account)
    
    @sp.entry_point
    def removeFromWhitelist(self, params):
        sp.verify(self.has_role(WHITELIST_ADMIN_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))

        sp.if self.data.token_whitelist.contains(params.token):
            self.data.token_whitelist[params.token].remove(params.account)
     
    @sp.entry_point
    def addToBlacklist(self, params):
        sp.verify(self.has_role(BLACKLIST_ADMIN_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))

        self.data.blacklist.add(params.account)
    
    @sp.entry_point
    def removeFromBlacklist(self, params):
        sp.verify(self.has_role(BLACKLIST_ADMIN_ROLE, sp.sender) | self.has_role(ADMIN_ROLE, sp.sender))

        self.data.blacklist.remove(params.account)

    @sp.entry_point
    def assertValid(self, params):
        sp.verify(~self.data.blacklist.contains(params.account))
        sp.verify(self.data.token_whitelist.contains(params.token))
        sp.verify(self.data.token_whitelist[params.token].contains(params.account))


class TestToken(sp.Contract):
    def __init__(self, registery):
        self.init(registery=registery)
    
    @sp.entry_point
    def transfer(self, params):
        # controller should be able to move tokens out of a blocked address
        c = sp.contract(
            t = sp.TAddress, 
            address = self.data.registery, 
            entry_point = "assertValid"
        ).open_some()
                    
        sp.transfer(
            params.from_,
            sp.mutez(0),
            c
        )
                    
        sp.transfer(
            params.to_,
            sp.mutez(0),
            c
        )
        

if "templates" not in __name__:
    @sp.add_test(name="Whitelist", is_default=True)
    def test():
        pass

    sp.add_compilation_target(
        "Whitelist_compiled", 
        Whitelist(
            administrators = sp.set([sp.address("tz1f6KNARa6KykKhoxAugtKwohmEfz8jrvUH")])
        )
    )

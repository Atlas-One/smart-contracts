
import smartpy as sp


class WhitelistValidator(sp.Contract):

    @sp.entry_point
    def assertTransfer(self, params):
        sp.set_type(
            params, 
            sp.TRecord(
                from_=sp.TAddress,
                to_=sp.TAddress,
                operator=sp.TAddress
            )
        )

        c = sp.contract(
            t = sp.TAddress, 
            address = self.data.whitelist_address, 
            entry_point = "assertValid"
        ).open_some()

        sp.transfer(
            params.to_,
            sp.mutez(0),
            c
        )

        sp.transfer(
            params.from_,
            sp.mutez(0),
            c
        )


class TestToken(sp.Contract):
    def __init__(self, validator, controller):
        self.init(validator=validator, controller=controller)
    
    @sp.entry_point
    def transfer(self, params):
        # controller should be able to move tokens out of a blocked address
        c = sp.contract(
            t = sp.TRecord(
                from_=sp.TAddress,
                to_=sp.TAddress,
                operator=sp.TAddress
            ), 
            address = self.data.validator, 
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
    @sp.add_test(name="WhitelistValidator", is_default=True)
    def test():
        pass

    sp.add_compilation_target(
        "WhitelistValidator_compiled", 
        WhitelistValidator()
    )

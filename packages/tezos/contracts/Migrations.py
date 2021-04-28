import smartpy as sp

class Migrations(sp.Contract):
    def __init__(self, owner):
        self.init(
            owner = owner,
            last_completed_migration = ""
        )
    
    def setCompleted(self, completed):
        sp.verify(sp.sender == self.data.owner)
        self.data.last_completed_migration = completed

if "templates" not in __name__:
    sp.add_compilation_target(
        "Migrations_compiled",
        Migrations(sp.address("tz1"))
    )
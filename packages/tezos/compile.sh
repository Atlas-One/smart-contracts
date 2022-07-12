#!/bin/bash

~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/Migrations.py $(PWD)/build/migrations --purge $@
~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/compliance/Whitelist.py $(PWD)/build/compliance --purge $@
~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/extension/WhitelistValidator.py $(PWD)/build/extension --purge $@
~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/token/FA1.2.py $(PWD)/build/token --purge $@
~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/wallet/VestingEscrowMinterBurnerWallet.py $(PWD)/build/wallet --purge $@

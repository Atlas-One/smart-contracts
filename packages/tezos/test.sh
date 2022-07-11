#!/bin/bash

~/smartpy-cli/SmartPy.sh test $(PWD)/contracts/compliance/Whitelist.py $(PWD)/smartpy-test-output/compliance --purge
~/smartpy-cli/SmartPy.sh test $(PWD)/contracts/extension/WhitelistValidator.py $(PWD)/smartpy-test-output/extension --purge
~/smartpy-cli/SmartPy.sh test $(PWD)/contracts/token/FA1.2.py $(PWD)/smartpy-test-output/token --purge
~/smartpy-cli/SmartPy.sh test $(PWD)/contracts/wallet/VestingEscrowMinterBurnerWallet.py $(PWD)/smartpy-test-output/wallet --purge

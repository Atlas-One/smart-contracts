#!/bin/bash

~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/Migrations.py $(PWD)/build/migrations --purge
~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/extension/GeneralTransferManager.py $(PWD)/build/extension --purge
~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/token/FA1.2.py $(PWD)/build/token --purge
~/smartpy-cli/SmartPy.sh compile $(PWD)/contracts/wallet/VestingEscrowWallet.py $(PWD)/build/wallet --purge

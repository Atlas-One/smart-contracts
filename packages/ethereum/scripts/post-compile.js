const fs = require("fs");

const contracts = {
  ERC1400WithoutIntrospection: "ethereum/token/ERC1400_ERC20Compatible",
  ERC1400WithIntrospection: "ethereum/token/ERC1400_ERC777Compatible",
  GeneralTransferManager: "ethereum/extension/GeneralTransferManager",
  VestingEscrowWallet: "ethereum/wallet/VestingEscrowWallet",
};

for (const [contractName, outputPath] of Object.entries(contracts)) {
  const compile = require(`${__dirname}/../build/${contractName}.json`);
  fs.writeFileSync(
    `${__dirname}/../dist/${outputPath}.abi`,
    JSON.stringify(compile.abi, null, 2)
  );
  fs.writeFileSync(
    `${__dirname}/../dist/${outputPath}.bin`,
    compile.bytecode.slice(2)
  );
}

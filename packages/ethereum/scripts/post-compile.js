const fs = require("fs");

const contracts = {
  SecurityToken: "ethereum/token",
  WhitelistUpgradeable: "ethereum/compliance",
  WhitelistValidator: "ethereum/extension",
  VestingEscrowMinterBurnerWallet:
    "ethereum/wallet",
};

for (const [contractName, outputPath] of Object.entries(contracts)) {
  const compile = require(`${__dirname}/../build/contracts/${contractName}.json`);
  fs.mkdirSync(`${__dirname}/../dist/${outputPath}`, { recursive: true });
  fs.writeFileSync(
    `${__dirname}/../dist/${outputPath}/${contractName}.abi`,
    JSON.stringify(compile.abi, null, 2)
  );
  fs.writeFileSync(
    `${__dirname}/../dist/${outputPath}/${contractName}.bin`,
    compile.bytecode.slice(2)
  );
}

require("dotenv").config();
const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function compile() {

  if (!process.env.MODULE_PUBLISHER_ACCOUNT_ADDRESS) {
    throw new Error(
      "MODULE_PUBLISHER_ACCOUNT_ADDRESS variable is not set, make sure you have set the publisher account address",
    );
  }

  const move = new cli.Move();

  await move.compile({
    packageDirectoryPath: "contract",
    namedAddresses: {
      // Compile module with account address
      iot_dapp: process.env.MODULE_PUBLISHER_ACCOUNT_ADDRESS,
      std: "0x1", // Explicitly map std to 0x1
      aptos_stdlib: "0x1", // Explicitly map aptos_stdlib to 0x1
    },
  });
}
compile();

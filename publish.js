require("dotenv").config();
const fs = require("node:fs");
const aptosSDK = require("@aptos-labs/ts-sdk")

async function publish() {

  if (!process.env.MODULE_PUBLISHER_ACCOUNT_ADDRESS) {
    throw new Error(
      "MODULE_PUBLISHER_ACCOUNT_PRIVATE_KEY variable is not set, make sure you have set the publisher account address",
    );
  }

  if (!process.env.MODULE_PUBLISHER_ACCOUNT_PRIVATE_KEY) {
    throw new Error(
      "MODULE_PUBLISHER_ACCOUNT_PRIVATE_KEY variable is not set, make sure you have set the publisher account private key",
    );
  }

  const publisherAddress = process.env.MODULE_PUBLISHER_ACCOUNT_ADDRESS;
  const privateKey = process.env.MODULE_PUBLISHER_ACCOUNT_PRIVATE_KEY;
  const nodeUrl = aptosSDK.NetworkToNodeAPI[process.env.APP_NETWORK];

  const command = `aptos move publish --package-dir contract --named-addresses iot_dapp=${publisherAddress} --private-key ${privateKey} --url ${nodeUrl}`;

  const { exec } = require('child_process');

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`exec error: ${error}`);
      return;
    }
    console.log(`stdout: ${stdout}`);
    console.error(`stderr: ${stderr}`);

    const filePath = ".env";
    let envContent = "";

    // Check .env file exists and read it
    if (fs.existsSync(filePath)) {
      envContent = fs.readFileSync(filePath, "utf8");
    }

    // Regular expression to match the MODULE_ADDRESS variable
    const regex = /^MODULE_ADDRESS=.*$/m;
    const newEntry = `MODULE_ADDRESS=${publisherAddress}`;

    // Check if MODULE_ADDRESS is already defined
    if (envContent.match(regex)) {
      // If the variable exists, replace it with the new value
      envContent = envContent.replace(regex, newEntry);
    } else {
      // If the variable does not exist, append it
      envContent += `\n${newEntry}`;
    }

    // Write the updated content back to the .env file
    fs.writeFileSync(filePath, envContent, "utf8");
  });
}
publish();

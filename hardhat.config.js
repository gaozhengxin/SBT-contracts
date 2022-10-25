require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-waffle");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.14",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    allowUnlimitedContractSize: true
  },
};

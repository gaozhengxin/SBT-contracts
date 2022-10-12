const { expect } = require("chai");
/*
describe("IDNFT V2", function () {
  it("Test IDNFT", async function () {
    const [owner] = await ethers.getSigners();

    console.log("owner " + owner.address);

    // deploy proxy admin
    console.log("\ndeploy proxy admin");
    let ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
    let proxyAdmin = await ProxyAdmin.deploy();
    console.log("proxy admin " + proxyAdmin.address);

    // deploy v1 idnft
    console.log("\ndeploy idnft v1");
    let IDNFT_Logic = await ethers.getContractFactory("IDNFT_v1");
    let idnft_logic = await IDNFT_Logic.deploy();
    console.log("idnft logic v1 " + idnft_logic.address);

    const Proxy = await ethers.getContractFactory("contracts/proxy/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy");
    let i_init = new ethers.utils.Interface(["function initialize()"]);

    let initdata = i_init.encodeFunctionData("initialize");
    console.log("initdata " + initdata);

    let idnft_proxy = await Proxy.deploy(idnft_logic.address, proxyAdmin.address, initdata);
    console.log("idnft_proxy " + idnft_proxy.address);

    let idnft = await ethers.getContractAt("IDNFT_v1", idnft_proxy.address);
    console.log("idnft " + idnft.address);


    // config idnft roles
    console.log("\nconfig idnft roles");

    // deploy v1 sbt
    // config roles
    // claim tokens
    // allocate sbt points
    // upgrade to v2
    // check roles
    // check idnft
    // check sbt
  });
});
*/
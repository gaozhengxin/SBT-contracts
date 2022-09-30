const { expect } = require("chai");

describe("IDNFT V2", function () {
  it("Test IDNFT", async function () {
    const [owner] = await ethers.getSigners();

    // deploy proxy admin
    let ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
    let proxyAdmin = await ProxyAdmin.deploy();
    console.log("proxy admin " + proxyAdmin.address);

    // deploy idnft
    let IDNFT_Logic = await ethers.getContractFactory("IDCard_V2");
    let idnft_logic = await IDNFT_Logic.deploy();
    console.log("idnft logic " + idnft_logic.address);

    const Proxy = await ethers.getContractFactory("contracts/proxy/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy");

    let i_init = new ethers.utils.Interface(["function initialize()"]);

    let initdata = i_init.encodeFunctionData("initialize");
    console.log("initdata " + initdata);

    let idnft_proxy = await Proxy.deploy(idnft_logic.address, proxyAdmin.address, initdata);
    console.log("idnft_proxy " + idnft_proxy.address);

    console.log(idnft_logic._abiCoder);
    let idnft = await ethers.getContractAt("IDCard_V2", idnft_proxy.address);

    // deploy manager
    let Manager_Logic = await ethers.getContractFactory("IDCard_V2_Manager");
    let manager_logic = await Manager_Logic.deploy();
    console.log("manager logic " + manager_logic.address);

    let manager_proxy = await Proxy.deploy(manager_logic.address, proxyAdmin.address, initdata);
    console.log("manager proxy " + manager_proxy.address);

    let manager = await ethers.getContractAt("IDCard_V2_Manager", manager_proxy.address);

    // deploy pseudo message channel
    let MC = await ethers.getContractFactory("PseudoMessageChannel");
    let mc = await MC.deploy();
    console.log("message channel " + mc.address);

    // config idnft
    let role_manager = await idnft.ROLE_MANAGER();
    console.log("Role manager " + role_manager);
    console.log("manager address " + manager.address);
    console.log("manager proxy address " + manager_proxy.address);
    await idnft.grantRole(role_manager, manager.address);
    expect(await idnft.hasRole(role_manager, manager.address)).to.equal(true);

    // config manager

    // deploy babt
    const BABT = await ethers.getContractFactory("BABT");

    // claim babt 1

    // claim idnft with babt 1

    // claim babt 2

    // update binding babt

    // claim babt 3

    // claim idnft with babt 3

    // merge idnft

    // remote login

    // simulate receive login message

    // simulate receive merge message

  });
});
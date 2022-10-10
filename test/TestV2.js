const { expect } = require("chai");

describe("IDNFT V2", function () {
  it("Test IDNFT", async function () {
    const [owner] = await ethers.getSigners();

    console.log("owner " + owner.address);

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

    let idnft = await ethers.getContractAt("IDCard_V2", idnft_proxy.address);
    console.log("idnft " + idnft.address);

    // deploy controller
    let Controller_Logic = await ethers.getContractFactory("IDCard_V2_Controller");
    let controller_logic = await Controller_Logic.deploy();
    console.log("controller logic " + controller_logic.address);

    let controller_proxy = await Proxy.deploy(controller_logic.address, proxyAdmin.address, initdata);
    console.log("controller proxy " + controller_proxy.address);

    let controller = await ethers.getContractAt("IDCard_V2_Controller", controller_proxy.address);
    console.log("controller address " + controller.address);

    // deploy pseudo message channel
    let MC = await ethers.getContractFactory("PseudoMessageChannel");
    let mc = await MC.deploy();
    console.log("message channel " + mc.address);

    // check idnft role
    let role_default_admin = await idnft.DEFAULT_ADMIN_ROLE();
    console.log("role default admin " + role_default_admin);

    expect(await idnft.hasRole(role_default_admin, owner.address)).to.equal(true);

    // grant idnft admin role
    let role_admin = await idnft.ROLE_ADMIN();
    console.log("role admin " + role_admin);
    await idnft.grantRole(role_admin, owner.address);
    expect(await idnft.hasRole(role_admin, owner.address)).to.equal(true);

    // grant idnft controller role
    let role_controller = await idnft.ROLE_CONTROLLER();
    console.log("role controller " + role_controller);
    await idnft.grantRole(role_controller, controller.address);
    expect(await idnft.hasRole(role_controller, controller.address)).to.equal(true);

    // init idnft
    await idnft.initV2(false);
    expect(await idnft._baseURI_()).to.equal("ipfs://QmTYwELcSgghx32VMsSGgWFQvCAqZ5tg6kKaPh2MSJfwAj/");

    // grant controller admin role
    await controller.grantRole(role_admin, owner.address);
    expect(await idnft.hasRole(role_admin, owner.address)).to.equal(true);

    // config controller
    await controller.initV2Controller(idnft.address, mc.address);

    // deploy babt
    const BABT = await ethers.getContractFactory("BABT");
    let babt = await BABT.deploy();
    console.log("BABT " + babt.address);

    // deploy BABT adaptor
    let BABTAdaptor = await ethers.getContractFactory("BABTAdaptor");
    let babtAdaptor = await BABTAdaptor.deploy(idnft.address, controller.address, babt.address);
    console.log("BABT adaptor " + babtAdaptor.address);

    // register BABT adaptor
    await controller.setDIDAdaptor("BABT", babtAdaptor.address);

    // claim babt 0
    await babt.claim(0);
    expect(await babt.ownerOf(0)).to.equal(owner.address);

    // claim idnft with babt 0
    let type_babt = await controller.dIDType("BABT");
    console.log("Type BABT " + type_babt);
    let signInfo_0 = await babtAdaptor.getSignInfo(0);
    console.log("Sign info 0 " + signInfo_0);
    let tx = await controller.claim(type_babt, signInfo_0);
    const rc = await tx.wait(); // 0ms, as tx is already confirmed
    const event = rc.events.find(event => event.event === 'Claim');
    const [tokenId, tokenOwner] = event.args;
    console.log("Token id " + tokenId); // 31337000000000
    console.log("Token owner " + tokenOwner);
    expect(await idnft.ownerOf(tokenId)).to.equal(owner.address);
    expect(await controller.verifyAccount(tokenId)).to.equal(true);

    // claim babt 1
    await babt.claim(1);
    expect(await babt.ownerOf(1)).to.equal(owner.address);
    let signInfo_1 = await babtAdaptor.getSignInfo(1);
    console.log("Sign info 1 " + signInfo_1);

    // burn babt 0
    await babt.burn(0);
    expect(await controller.verifyAccount(tokenId)).to.equal(false);
  
    // update binding babt
    await controller.updateAccountInfo(tokenId, type_babt, signInfo_1);
    expect(await controller.verifyAccount(tokenId)).to.equal(true);

    // claim babt 2

    // claim idnft with babt 2

    // merge idnft

    // remote login

    // simulate receive login message

    // simulate receive merge message

  });
});
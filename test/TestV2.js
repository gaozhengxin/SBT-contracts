const { expect } = require("chai");

describe("IDNFT V2", function () {
  it("Test IDNFT", async function () {
    const [owner] = await ethers.getSigners();

    console.log("owner " + owner.address);

    // deploy proxy admin
    console.log("\ndeploy proxy admin");
    let ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
    let proxyAdmin = await ProxyAdmin.deploy();
    console.log("proxy admin " + proxyAdmin.address);

    // deploy idnft
    console.log("\ndeploy idnft");
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
    console.log("\ndeploy controller");
    let Controller_Logic = await ethers.getContractFactory("IDCard_V2_Controller");
    let controller_logic = await Controller_Logic.deploy();
    console.log("controller logic " + controller_logic.address);

    let controller_proxy = await Proxy.deploy(controller_logic.address, proxyAdmin.address, initdata);
    console.log("controller proxy " + controller_proxy.address);

    let controller = await ethers.getContractAt("IDCard_V2_Controller", controller_proxy.address);
    console.log("controller address " + controller.address);

    // deploy pseudo message channel
    console.log("\ndeploy pseudo message channel");
    let MC = await ethers.getContractFactory("PseudoMessageChannel");
    let mc = await MC.deploy();
    console.log("message channel " + mc.address);

    // check idnft role
    console.log("\ncheck idnft role");
    let role_default_admin = await idnft.DEFAULT_ADMIN_ROLE();
    console.log("role default admin " + role_default_admin);

    expect(await idnft.hasRole(role_default_admin, owner.address)).to.equal(true);

    // grant idnft admin role
    console.log("\ngrant idnft admin role");
    let role_admin = await idnft.ROLE_ADMIN();
    console.log("role admin " + role_admin);
    await idnft.grantRole(role_admin, owner.address);
    expect(await idnft.hasRole(role_admin, owner.address)).to.equal(true);

    // grant idnft controller role
    console.log("\ngrant idnft controller role");
    let role_controller = await idnft.ROLE_CONTROLLER();
    console.log("role controller " + role_controller);
    await idnft.grantRole(role_controller, controller.address);
    expect(await idnft.hasRole(role_controller, controller.address)).to.equal(true);

    // init idnft
    console.log("\ninit idnft");
    await idnft.initV2(false);
    expect(await idnft._baseURI_()).to.equal("ipfs://QmTYwELcSgghx32VMsSGgWFQvCAqZ5tg6kKaPh2MSJfwAj/");

    // grant controller admin role
    console.log("\ngrant controller admin role");
    await controller.grantRole(role_admin, owner.address);
    expect(await idnft.hasRole(role_admin, owner.address)).to.equal(true);

    // config controller
    console.log("\nconfig controller");
    await controller.initV2Controller(idnft.address, mc.address);

    // set chains
    console.log("\nset chains");
    await controller.setChains([627]);

    // set caller permission
    console.log("\nset caller permission");
    let func_merge = await controller.FuncMerge();
    console.log("func merge " + func_merge);
    await controller.setCallerPermission(mc.address, func_merge, true);
    let func_login = await controller.FuncLogin();
    console.log("func login " + func_login);
    await controller.setCallerPermission(mc.address, func_login, true);

    // deploy babt
    console.log("\ndeploy babt");
    const BABT = await ethers.getContractFactory("BABT");
    let babt = await BABT.deploy();
    console.log("BABT " + babt.address);

    // deploy BABT adaptor
    console.log("\ndeploy BABT adaptor");
    let BABTAdaptor = await ethers.getContractFactory("BABTAdaptor");
    let babtAdaptor = await BABTAdaptor.deploy(idnft.address, controller.address, babt.address);
    console.log("BABT adaptor " + babtAdaptor.address);

    // register BABT adaptor
    console.log("\nregister BABT adaptor");
    await controller.setDIDAdaptor("BABT", babtAdaptor.address);

    // claim babt 0
    console.log("\nclaim babt 0");
    await babt.claim(0);
    expect(await babt.ownerOf(0)).to.equal(owner.address);

    // claim idnft with babt 0
    console.log("\nclaim idnft with babt 0");
    let type_babt = await controller.dIDType("BABT");
    console.log("Type BABT " + type_babt);

    let signInfo_0 = await babtAdaptor.getSignInfo(0);
    console.log("Sign info 0 " + signInfo_0);

    let tx = await controller.claim(type_babt, signInfo_0);
    const rc = await tx.wait(); // 0ms, as tx is already confirmed
    const event = rc.events.find(event => event.event === 'Claim');
    const [tokenId0, tokenOwner0] = event.args;
    console.log("Token id 0 " + tokenId0); // 31337000000000
    console.log("Token owner " + tokenOwner0);

    expect(await idnft.ownerOf(tokenId0)).to.equal(owner.address);
    expect(await controller.verifyAccount(tokenId0)).to.equal(true);

    // claim babt 1
    console.log("\nclaim babt 1");
    await babt.claim(1);
    expect(await babt.ownerOf(1)).to.equal(owner.address);
    let signInfo_1 = await babtAdaptor.getSignInfo(1);
    console.log("Sign info 1 " + signInfo_1);

    // burn babt 0
    console.log("\nburn babt 0");
    await babt.burn(0);
    expect(await controller.verifyAccount(tokenId0)).to.equal(false);

    // update binding babt
    console.log("\nupdate binding babt");
    await controller.updateAccountInfo(tokenId0, type_babt, signInfo_1);
    expect(await controller.verifyAccount(tokenId0)).to.equal(true);

    // claim babt 2
    console.log("\nclaim babt 2");
    await babt.claim(2);
    expect(await babt.ownerOf(2)).to.equal(owner.address);

    // claim idnft with babt 2
    console.log("\nclaim idnft with babt 2");
    let signInfo_2 = await babtAdaptor.getSignInfo(2);
    console.log("Sign info 2 " + signInfo_2);

    let tx2 = await controller.claim(type_babt, signInfo_2);
    const rc2 = await tx2.wait(); // 0ms, as tx is already confirmed
    const event2 = rc2.events.find(event => event.event === 'Claim');
    const [tokenId1, tokenOwner1] = event2.args;
    console.log("Token id 1 " + tokenId1); // 31337000000001
    console.log("Token owner " + tokenOwner1);

    // deploy SBT
    console.log("\ndeploy SBT");
    let MultiHonor_Multichain = "contracts/SBT/bsc/MultiHonor.sol:MultiHonor_Multichain";
    let SBT_Logic = await ethers.getContractFactory(MultiHonor_Multichain);
    let sbt_logic = await SBT_Logic.deploy();
    console.log("sbt logic " + sbt_logic.address);

    let sbt_proxy = await Proxy.deploy(sbt_logic.address, proxyAdmin.address, initdata);
    console.log("sbt proxy " + sbt_proxy.address);

    let sbt = await ethers.getContractAt(MultiHonor_Multichain, sbt_proxy.address);
    console.log("sbt address " + sbt.address);

    // grant roles to owner
    console.log("\ngrant roles to owner");
    let role_set_poc = await sbt.ROLE_SET_POC();
    console.log("role set poc " + role_set_poc);
    let role_set_event = await sbt.ROLE_SET_EVENT();
    console.log("role set event " + role_set_event);

    await sbt.grantRole(role_set_poc, owner.address);
    expect(await sbt.hasRole(role_set_poc, owner.address)).to.equal(true);

    await sbt.grantRole(role_set_event, owner.address);
    expect(await sbt.hasRole(role_set_event, owner.address)).to.equal(true);

    // set controller
    await sbt.setIDController(controller.address);
    expect(await sbt.controller()).to.equal(controller.address);

    // register ledger
    controller.registerLedgers(sbt.address);

    // allocate SBT points to idnft tokenId0 and tokenId1
    console.log("\nallocate SBT points to idnft 0 and 1");
    await sbt.setPOC([tokenId0, tokenId1], [100, 200]);
    await sbt.setEventPoint([tokenId0, tokenId1], [300, 400]);
    console.log(await sbt.TotalPoint(tokenId0));
    console.log(await sbt.TotalPoint(tokenId1));
    // TotalPoint(tokenId0) = 0.6*100 + 0.1*300 = 90
    expect(await sbt.TotalPoint(tokenId0)).to.equal(90);
    // TotalPoint(tokenId1) = 0.6*200 + 0.1*400 = 160
    expect(await sbt.TotalPoint(tokenId1)).to.equal(160);

    // merge idnft tokenId1 to tokenId0
    console.log("\nmerge idnft tokenId1 to tokenId0");
    let tx3 = await controller.merge(tokenId1, tokenId0);
    let rc3 = await tx3.wait();
    expect(await idnft.balanceOf(owner.address)).to.equal(1);
    //expect(await sbt.POC(tokenId0)).to.equal(400); // sbt.POC is not a function, strange
    expect(await sbt.EventPoint(tokenId0)).to.equal(700);
    expect(await sbt.EventPoint(tokenId1)).to.equal(0);
    expect(await sbt.TotalPoint(tokenId0)).to.equal(250);
    expect(await sbt.TotalPoint(tokenId1)).to.equal(0);

    // check log: sending merge message
    console.log("\ncheck log: sending merge message");
    let topic_send = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Send(uint256,bytes)"));
    console.log("topic send " + topic_send);
    const event3 = rc3.events.find(event => event.address === mc.address);

    const [topic_0] = event3.topics;
    expect(topic_0).to.equal(topic_send);

    var abi = ["event Send(uint256 toChainID, bytes message)"];
    var iface = new ethers.utils.Interface(abi);
    let event_send = iface.parseLog(event3);

    let [toChainID, message] = event_send.args;
    expect(toChainID).to.equal(627);
    console.log("message " + message);
    expect(message).to.equal(
      ethers.utils.defaultAbiCoder.encode(
        ["bytes4", "bytes"],
        [0xf611b776, ethers.utils.defaultAbiCoder.encode(
          ["uint256", "uint256"],
          [tokenId1, tokenId0]
        )]
      )
    );

    // remote login

    // check log: sending remote login message

    // simulate receive login message

    // simulate receive merge message
    // 1. both tokens exist
    // 2. either token does not exist

  });
});
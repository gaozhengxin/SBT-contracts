const { expect } = require("chai");

describe("IDNFT V2 upgrade", function () {
  it("Test IDNFT upgrade", async function () {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    console.log("owner " + owner.address);
    console.log("addr1 " + addr1.address);
    console.log("addr2 " + addr2.address);
    console.log("addr3 " + addr3.address);

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

    // deploy v1 sbt
    console.log("\ndeploy v1 sbt");

    let SBT_Logic = await ethers.getContractFactory("MultiHonor_V1");
    let sbt_logic = await SBT_Logic.deploy();
    console.log("sbt logic v1 " + sbt_logic.address);

    let sbt_proxy = await Proxy.deploy(sbt_logic.address, proxyAdmin.address, initdata);
    console.log("sbt_proxy " + sbt_proxy.address);

    let sbt = await ethers.getContractAt("MultiHonor_V1", sbt_proxy.address);
    console.log("sbt " + sbt.address);

    // config roles
    console.log("\nconfig sbt roles");
    let role_set_poc = await sbt.ROLE_SET_POC();
    console.log("role set poc " + role_set_poc);
    await sbt.grantRole(role_set_poc, owner.address);
    expect(await sbt.hasRole(role_set_poc, owner.address)).to.equal(true);

    // claim idnfts
    console.log("\nclaim idnfts");
    await idnft.connect(addr1).claim();
    expect(await idnft.ownerOf(0)).to.equal(addr1.address);
    console.log(addr1.address + ":" + 0);

    await idnft.connect(addr2).claim();
    expect(await idnft.ownerOf(1)).to.equal(addr2.address);
    console.log(addr2.address + ":" + 1);

    await idnft.connect(addr3).claim();
    expect(await idnft.ownerOf(2)).to.equal(addr3.address);
    console.log(addr3.address + ":" + 2);

    expect(await idnft.totalSupply()).to.equal(3);
    console.log("total supply: " + 3);

    // allocate sbt points
    console.log("\nallocate sbt points");
    await sbt.setPOC([0, 1, 2], [300, 500, 700]);
    expect(await sbt.POC_2(0)).to.equal(300);
    console.log("poc of 0: 300");
    expect(await sbt.TotalPoint(0)).to.equal(180);
    console.log("total of 0: 180");
    expect(await sbt.POC_2(1)).to.equal(500);
    console.log("poc of 1: 500");
    expect(await sbt.TotalPoint(1)).to.equal(300);
    console.log("total of 1: 300");
    expect(await sbt.POC_2(2)).to.equal(700);
    console.log("poc of 2: 700");
    expect(await sbt.TotalPoint(2)).to.equal(420);
    console.log("total of 2: 420");

    // upgrade idnft to v2
    console.log("\nupgrade idnft");
    let IDNFT_Logic_V2 = await ethers.getContractFactory("IDCard_V2");
    let idnft_logic_v2 = await IDNFT_Logic_V2.deploy();
    console.log("idnft logic v2 " + idnft_logic_v2.address);

    await proxyAdmin.upgrade(idnft.address, idnft_logic_v2.address);
    let idnft_v2 = await ethers.getContractAt("IDCard_V2", idnft_proxy.address);
    console.log("idnft_v2 " + idnft_v2.address);

    await idnft_v2.initV2();

    let baseurl = await idnft_v2._baseURI_();
    expect(baseurl).to.equal("ipfs://QmTYwELcSgghx32VMsSGgWFQvCAqZ5tg6kKaPh2MSJfwAj/");
    console.log("baseurl " + baseurl);

    expect(await idnft.ownerOf(0)).to.equal(addr1.address);
    console.log(addr1.address + ":" + 0);
    expect(await idnft.ownerOf(1)).to.equal(addr2.address);
    console.log(addr2.address + ":" + 1);
    expect(await idnft.ownerOf(2)).to.equal(addr3.address);
    console.log(addr3.address + ":" + 2);
    expect(await idnft.totalSupply()).to.equal(3);
    console.log("total supply: " + 3);

    // upgrade sbt to v2
    console.log("\nupgrade sbt");
    let SBT_V2 = await ethers.getContractFactory("contracts/SBT/polygon/MultiHonor.sol:MultiHonor_Multichain");
    let sbt_logic_v2 = await SBT_V2.deploy();
    console.log("sbt_v2 logic v2 " + sbt_logic_v2.address);

    await proxyAdmin.upgrade(sbt.address, sbt_logic_v2.address);
    let sbt_v2 = await ethers.getContractAt("contracts/SBT/polygon/MultiHonor.sol:MultiHonor_Multichain", sbt_proxy.address);
    console.log("sbt_v2 " + sbt_v2.address);

    expect(await sbt.hasRole(role_set_poc, owner.address)).to.equal(true);
  });
});

const { expect } = require("chai");

describe("IDNFT V2", function () {
  it("Test IDNFT", async function () {
    const [owner] = await ethers.getSigners();

    const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
    const proxyAdmin = await ProxyAdmin.deploy();
    console.log("proxy admin " + proxyAdmin.address);

    const IDNFT_Logic = await ethers.getContractFactory("IDCard_V2_Core");
    const idnft_logic = await IDNFT_Logic.deploy();
    console.log("idnft logic " + idnft_logic.address);

    const Proxy = await ethers.getContractFactory("TransparentUpgradeableProxy");
    const initdata = idnft_logic.initialize.encode();
    const idnft = await Proxy.deploy(idnft_logic.address, proxyAdmin.address, initdata);
    console.log("idnft " + idnft.address);
    //const ownerBalance = await hardhatToken.balanceOf(owner.address);
    //expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
  });
});
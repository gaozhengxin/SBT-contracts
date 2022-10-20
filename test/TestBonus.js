const { expect } = require("chai");

describe("Test DAO contracts V1", function () {
  it("Test Date time", async function () {
    const [owner] = await ethers.getSigners();
    console.log("owner " + owner.address);

    // deploy data time
    console.log("\ndeploy data time");
    let DateTime = await ethers.getContractFactory("DateTime");
    let dateTime = await DateTime.deploy();

    // 1970/1/1
    let ts_0 = await dateTime.toTimestamp1(1970, 1, 1);
    expect(ts_0).to.equal(0);
    // 1900/1/1
    let ts_1 = await dateTime.toTimestamp1(1900, 1, 1);
    expect(ts_1).to.equal(0);
    // 2000/2/29
    let ts_2 = await dateTime.toTimestamp1(2000, 2, 29);
    expect(ts_2).to.equal(951782400);
    expect(await dateTime.getMonth(951782400)).to.equal(2);
    expect(await dateTime.getDay(951782400)).to.equal(29);
    // 2020/3/1
    let ts_3 = await dateTime.toTimestamp1(2020, 3, 1);
    expect(ts_3).to.equal(1583020800);
    expect(await dateTime.getMonth(1583020800)).to.equal(3);
    expect(await dateTime.getDay(1583020800)).to.equal(1);
    // 2025/7/1
    let ts_4 = await dateTime.toTimestamp1(2025, 7, 1);
    expect(ts_4).to.equal(1751328000);
    expect(await dateTime.getMonth(1751328000)).to.equal(7);
    expect(await dateTime.getDay(1751328000)).to.equal(1);
    // 2030/10/1
    let ts_5 = await dateTime.toTimestamp1(2030, 10, 20);
    expect(await dateTime.getMonth(1918684800)).to.equal(10);
    expect(await dateTime.getDay(1918684800)).to.equal(20);
  });

  it("Test Bonus", async function () {
    const [owner] = await ethers.getSigners();
    console.log("owner " + owner.address);
  });
});
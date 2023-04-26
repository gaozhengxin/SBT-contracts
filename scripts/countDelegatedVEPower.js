// DelegatedVEPowerCounter

const hre = require("hardhat");

async function main() {
    const ethChainID = 1;
    const ftmChainID = 250;
    const bscChainID = 56;

    const epoch = 231;

    const ethMax = 380;
    const ftmMax = 320;
    const bscMax = 720;

    let counter = await ethers.getContractAt("DelegatedVEPowerCounter", "0xbe77ef94d16d2a3086c8089f3c14453bb3e4e156");

    var ethPower = 0;
    for (var i = 0; i * 50 < ethMax; i++) {
        const power = await counter.count(ethChainID, i * 50, (i + 1) * 50 - 1, epoch);
        ethPower += parseInt(power);
    }
    console.log(`ethPower : ${ethPower}`);

    var ftmPower = 0;
    for (var i = 0; i * 50 < ftmMax; i++) {
        const power = await counter.count(ftmChainID, i * 50, (i + 1) * 50 - 1, epoch);
        ftmPower += parseInt(power);
    }
    console.log(`ftmPower : ${ftmPower}`);

    var bscPower = 0;
    for (var i = 0; i * 50 < bscMax; i++) {
        const power = await counter.count(bscChainID, i * 50, (i + 1) * 50 - 1, epoch);
        bscPower += parseInt(power);
    }
    console.log(`bscPower : ${bscPower}`);

    console.log(`total delegated : ${ethPower + ftmPower + bscPower}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
const hre = require("hardhat");

async function main() {
  const PrivateVoting = await hre.ethers.getContractFactory("PrivateVoting");
  const pv = await PrivateVoting.deploy();
  await pv.deployed();
  console.log("PrivateVoting deployed to:", pv.address);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

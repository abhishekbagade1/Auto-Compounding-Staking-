
 import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
 import { expect } from "chai";
 import { ethers } from "hardhat";
 import { upgrades } from "hardhat";
 
 const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
 
 const truffleAssert = require("truffle-assertions");
 
 describe("Unit Tests", function () {
   let stakeToken: any, rewardToken: any, staking: any , admin: SignerWithAddress, user: SignerWithAddress;
 
 
   beforeEach(async function () {
     const signers: SignerWithAddress[] = await ethers.getSigners();
     admin = signers[0];
     user = signers[1];
 
     const tokenR = await ethers.getContractFactory("TraxToken");
     stakeToken = await tokenR.deploy( );
     await stakeToken.deployed();
     
     const tokenS = await ethers.getContractFactory("USDCToken");
     rewardToken = await tokenS.deploy();
     await rewardToken.deployed();
     
     //maxpresalelimit , mintoken, recieveradr, royaltyAmt
     const contract = await ethers.getContractFactory("StakingRewards");
     staking = await upgrades.deployProxy(
       contract,
       [stakeToken.address , rewardToken.address],
       {
         initializer: "initialize",
       },
     );
     await staking.deployed();
 
 
     const blockNumber = await ethers.provider.getBlockNumber();
     const { timestamp } = await ethers.provider.getBlock(blockNumber);
 
     const tx = await staking.setRewardsDuration(365*24*60*60);
     
     //     var x = parseInt((await tx.wait()).logs[0].data);

   });
 
   describe("Staking Rewards Unit Testing", () => {
     it("it should transfer rewards ", async function () {
       await stakeToken.transfer(user.address, ("2000000000000000000000")); //sent USDC tokens to user
       await rewardToken.transfer(staking.address , ("10000000000000000000000")); 
       var tx = await staking.connect(admin).setRewardsDuration(365*24*60*60);
       var txn = await tx.wait();
       var tx = await staking.connect(admin).setRewardAmount( "10000000000000000000000");


       var tx = await staking.connect(user).stake("1000000000000000000000");
       var txn = await tx.wait();

       await ethers.provider.send("evm_increaseTime", [10 * 24 * 60 * 60]);
       await ethers.provider.send("evm_mine");

       var tx = await staking.connect(user).claimRewards();
       var txn = await tx.wait();

       console.log("reward first time", parseInt(tx));

       await ethers.provider.send("evm_increaseTime", [10 * 24 * 60 * 60]);
       await ethers.provider.send("evm_mine");


       var tx = await staking.connect(user).stake("1000000000000000000000");
       var txn = await tx.wait();


       var tx = await staking.connect(user).claimRewards();
       var txn = await tx.wait();

       console.log("reward second time", parseInt(tx));

       tx = await rewardToken.connect(user).balanceOf();
       console.log("reward", parseInt(tx));


     });
   });
 });
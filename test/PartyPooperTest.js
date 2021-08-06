const { expect } = require("chai");

describe("PartyPooper", function () {

  const partyBidAddress = "0xf64863E64e0364A6eeF4F224551A5F949db41e2c"
  const aaveLendingPoolAddress = "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5";

  let partyBid;
  let marketWrapper;
  let partyPooper;
  let auctionId;
  let owner;
  let addr1;
  let addrs;


  beforeEach(async function () {

    const partyPooperFactory = await ethers.getContractFactory("PartyPooper");
    partyPooper = await partyPooperFactory.deploy(aaveLendingPoolAddress);
    partyBid = await ethers.getContractAt("IPartyBid", partyBidAddress);
    marketWrapper = await ethers.getContractAt("IMarketWrapper", await partyBid.marketWrapper());
    auctionId = await partyBid.auctionId();
    [owner, addr1, ...addrs] = await ethers.getSigners();
  });

  it("Should raise the highest bid", async function () {
     const minBidBefore = await marketWrapper.getMinimumBid(auctionId);
     await partyPooper.raisePartyBid(partyBidAddress);
     const minBidAfter = await marketWrapper.getMinimumBid(auctionId);
     expect(minBidAfter.gt(minBidBefore));
  });
});

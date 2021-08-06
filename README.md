# Party Pooper 

Value extraction from [PartyBid](https://github.com/PartyDAO/partybid)

## Context 

PartyBid is a protocol that allows users to pool their funds together to participate in an NFT auction. Anyone can contribute ETH to the PartyBid, and can trigger a bid from that party (which is always the minimum bid required to beat the next highest bidder).

A consequence of this mechanism is that the partybid can be forced to bid its full balance on the auction. This is a known mechanic of PartyBid, and was publicly disclosed in the project's [security review](https://hackmd.io/@alextowle/ryGQ4L-pd#PartyBid-Report). 

Party Pooper is an implementation of this value extraction mechanism that leverages flash loans. The contract has a single external method `raisePartyBid(address partyBid)` that works as follows: 

1. Take out flash loan 
2. Bid on auction
3. Trigger a higher bid from partybid 
4. Return loan 

This allows any third party to cause partybid to bid it's full balance on an auction. 
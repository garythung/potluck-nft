// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.3;
pragma experimental ABIEncoderV2;

import "abdk-libraries-solidity/ABDKMathQuad.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PotluckSettings.sol";

library Math {
  // Source: https://medium.com/coinmonks/math-in-solidity-part-3-percents-and-proportions-4db014e080b1
  // Calculates x * y / z. Useful for doing percentages like Amount * Percent numerator / Percent denominator
  // Example: Calculate 1.25% of 100 ETH (aka 125 basis points): mulDiv(100e18, 125, 10000)
  function mulDiv(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
    return ABDKMathQuad.toUInt(
      ABDKMathQuad.div(
        ABDKMathQuad.mul(
          ABDKMathQuad.fromUInt(x),
          ABDKMathQuad.fromUInt(y)
        ),
        ABDKMathQuad.fromUInt(z)
      )
    );
  }
}

contract PotluckPot is ERC721Holder, ERC1155Holder, ReentrancyGuard {
  // =============================
  // ========== STRUCTS ==========
  // =============================

  struct Contribution {
    uint256 index; // 1 indexed
    uint256 value;
    bool proceedsClaimed;
  }

  struct Bid {
    address bidder;
    uint256 amount;
    uint256 time;
  }

  // ===========================
  // ========== ENUMS ==========
  // ===========================

  enum Standard {
    ERC721,
    ERC1155
  }

  // fundraising is when people can contribute money
  // claimed is when the NFT is owned because the NFT owner fulfilled the bid
  // auctioning is when an auction is live to resell the NFT
  // settled is when the auction has been terminated and NFT resold
  enum State {
    fundraising,
    claimed,
    auctioning,
    settled
  }

  // =============================
  // ========== STORAGE ==========
  // =============================

  // ===== General information =====
  // Address of settings contract
  address payable public settingsAddress;
  // State of the pot
  State public state;
  // Creator of pot
  address public immutable creator;
  // NFT contract
  address public immutable nftAddress;
  // NFT token ID
  uint256 public immutable tokenID;
  // NFT token standard
  Standard public immutable standard;
  // Creation time
  uint256 public immutable timeCreated;

  // ===== Fundraising information =====
  // Current amount raised to buy the NFT
  uint256 public fundsRaised;
  // Stakes of those who have contributed to the pot
  mapping (address => Contribution) public contributions;
  // List of contributors
  address[] public contributors;
  // Fee from first sale
  uint256 public feeCollected;

  // ===== Reserve price information =====
  // Reserve price that each voter has chosen
  mapping (address => uint256) public reservePrices;
  // Log of addresses that have adjusted their reserve price. We need this because the
  // default reserve price is fundsRaised. However, we can't know this via the
  // reservePrices mapping because we don't initialize that value for each user
  mapping (address => bool) hasSetReservePrice;
  // Share of votes used to decide reserve price
  uint256 public votingShares;
  // Reserve price total amounts. Actual reserve price is total / shares
  uint256 public reserveTotal;

  // ===== Auction information =====
  // How long auctions will run for
  uint256 public auctionDuration;
  // Minimum percentage that a new bid must beat the highest bid by
  uint256 public minBidDeltaPercentage;
  // Time before auction end in which a new bid will extend the auction end time
  uint256 public extensionWindow;
  // Time that an auction will be extended from a near closing bid
  uint256 public extensionDuration;
  // Ending time of the auction
  uint256 public auctionEnd;
  // List of bids
  Bid[] public bids;
  // Refunds available to bidders
  mapping (address => uint256) public refunds;

  // ===============================
  // ========== MODIFIERS ==========
  // ===============================

  /**
   * Reverts if the caller is not in the pot.
   */
  modifier onlyContributor() {
    require(contributions[msg.sender].index > 0, "Pot: Must first be a contributor to do this.");
    _;
  }

  // ============================
  // ========== EVENTS ==========
  // ============================

  // Pot is created
  event PotCreated(address indexed creator, address indexed nftContract, uint256 indexed tokenID, uint256 initialFunding);

  // Someone contributes
  event PotContribution(address indexed member, uint256 value);

  // Someone withdraws their contribution
  event PotContributionWithdrawn(address indexed member, uint256 value);

  // NFT owner sells to the pot
  event PotContributionsClaimed(address indexed seller);

  // Contributor sets their NFT reserve price
  event PotReservePriceSet(address indexed member, uint256 price);

  // Auction starts to sell the NFT
  event PotAuctionStarted(address indexed buyer, uint256 value, uint256 time);

  // Someone bids on the NFT
  event PotBid(address indexed bidder, uint256 value, uint256 time);

  // Someone claimed their refund from bidding
  event PotRefundClaimed(address indexed bidder, uint256 value);

  // Someone formally settles the auction
  event PotAuctionSettled(address indexed buyer, uint256 value);

  // Contributor withdraws their proceeds from NFT sale
  event PotProceedsClaimed(address indexed member, uint256 proceeds);

  // =================================
  // ========== CONSTRUCTOR ==========
  // =================================

  constructor(
    address payable _settings,
    address _creator,
    address _nftAddress,
    uint256 _tokenID,
    Standard _standard
  ) payable {
    // Input safety checks
    require(Address.isContract(_nftAddress), "Pot: NFT address is invalid.");

    // If ERC721, check that it exists.
    // We can't do this for ERC1155 because the data doesn't have a viable access pattern
    // to do so.
    if (_standard == Standard.ERC721) {
      IERC721 UntrustedERC721 = IERC721(_nftAddress);
      require(UntrustedERC721.ownerOf(_tokenID) != address(0), "Pot: NFT does not exist.");
    }

    // Initialize general information
    settingsAddress = _settings;
    creator = _creator;
    nftAddress = _nftAddress;
    tokenID = _tokenID;
    standard = _standard;
    state = State.fundraising;
    timeCreated = block.timestamp;

    // Initialize funding information
    fundsRaised = 0;
    feeCollected = 0;

    // Initialize settings
    PotluckSettings settings = PotluckSettings(settingsAddress);
    minBidDeltaPercentage = settings.minBidDeltaPercentage();
    auctionDuration = settings.auctionDuration();
    extensionWindow = settings.extensionWindow();
    extensionDuration = settings.extensionDuration();

    if (msg.value > 0) {
      // Initialize reserve pricing
      votingShares = msg.value;

      fundsRaised = msg.value;
      addContribution(_creator, msg.value);
    }

    emit PotCreated(_creator, _nftAddress, _tokenID, msg.value);
  }

  // ===========================
  // ========== VIEWS ==========
  // ===========================

  function topBid() public view returns (Bid memory) {
    return bids[bids.length - 1];
  }

  /**
   * Reserve price based on weighted voting.
   */
  function reservePrice() public view returns (uint256) {
    return reserveTotal / votingShares;
  }

  /**
   * The minimum value that a new bid must be.
   */
  function minBid() public view returns (uint256) {
    if (bids.length == 0) {
      return reservePrice();
    }

    return (topBid().amount * (100 + minBidDeltaPercentage)) / 100;
  }

  /**
   * List of contributors
   */
  function contributorList() external view returns (address[] memory) {
    return contributors;
  }

  /**
   * List of bids
   */
  function bidList() external view returns (Bid[] memory) {
    return bids;
  }

  /**
   * Returns the contributor's reserve price
   */
  function contributorReservePrice(address _contributor) external view returns (uint256) {
    if (hasSetReservePrice[_contributor]) {
      return reservePrices[_contributor];
    } else {
      return fundsRaised;
    }
  }

  /**
   * Amount of proceeds available for a contributor to claim.
   */
  function contributorProceeds(address _contributor) public view returns (uint256) {
    Contribution memory contribution = contributions[_contributor];
    if (state != State.settled || contribution.index == 0 || contribution.proceedsClaimed) {
      return 0;
    }

    // Calculate proceeds based on contribution percentage
    return Math.mulDiv(topBid().amount, contribution.value, fundsRaised);
  }

  /**
   * Get LIVE fee amount from the sale, not the actual fee collected
   */
  function getLiveSaleFee() public view returns (uint256) {
    return Math.mulDiv(fundsRaised, PotluckSettings(settingsAddress).feeBasisPoints(), 1e4);
  }

  // =======================================
  // ========== STORAGE FUNCTIONS ==========
  // =======================================

  /**
   * Handles the logic for updating the contributor mapping and list when adding
   * a contribution.
   */
  function addContribution(address _sender, uint256 _value) internal {
    Contribution storage contribution = contributions[_sender];

    // Add to contribution value
    contribution.value += _value;

    // Existing contribution is present; do nothing
    if (contribution.index > 0) {
      return;
    }

    // Set up index for new contribution
    contributors.push(_sender);
    contribution.index = contributors.length; // index is 1-indexed
  }

  /**
   * Handles the logic for updating the contributor mapping and list when removing
   * a contribution.
   */
  function removeContribution(address _sender) internal {
    Contribution storage contribution = contributions[_sender];
    require(contribution.index != 0, "Pot: Contribution must exist.");
    require(contribution.index <= contributors.length, "Pot: Contribution data is out of sync.");

    // Move the last element of array into the empty slot
    uint256 removedIndex = contribution.index - 1;
    uint256 lastIndex = contributors.length - 1;
    contributions[contributors[lastIndex]].index = removedIndex + 1;
    contributors[removedIndex] = contributors[lastIndex];

    // Delete redundant/unused memory
    contributors.pop();
    delete contributions[_sender];
  }

  // ===========================================
  // ========== FUNDRAISING FUNCTIONS ==========
  // ===========================================

  /**
   * Contribute to the pot by sending ether.
   */
  function contribute() external payable {
    require(msg.value > 0, "Pot: Must send ether.");

    PotluckSettings settings = PotluckSettings(settingsAddress);
    if (settings.safeguarded()) {
      require(msg.value + fundsRaised <= settings.maxFundraising(), "Pot: Safeguard prevents fundraising beyond the limit.");
    }

    // Record contribution
    fundsRaised += msg.value;
    addContribution(msg.sender, msg.value);

    emit PotContribution(msg.sender, msg.value);
  }

  /**
   * Contributors can withdraw their contribution. They won't be able to contribute
   * again.
   */
  function withdrawContribution(uint256 _amount) external nonReentrant onlyContributor {
    require(state == State.fundraising, "Pot: Pot must be in fundraising mode.");

    // Get contribution value
    uint256 value = contributions[msg.sender].value;

    require(_amount <= value, "Pot: Withdrawal cannot exceed contribution");

    // Remove sender from records
    if (_amount == value) {
      removeContribution(msg.sender);
    } else {
      contributions[msg.sender].value -= _amount;
    }

    // Reduce fundraised amount
    fundsRaised -= _amount;

    // Send contribution back
    (bool success,) = msg.sender.call{ value: _amount }("");
    require(success, "Pot: Failed to send Ether.");

    emit PotContributionWithdrawn(msg.sender, value);
  }

  // =====================================
  // ========== CLAIM FUNCTIONS ==========
  // =====================================

  /**
   * Owner of the NFT can execute a sale to the pot.
   */
  function claimPot(uint256 _amount) external nonReentrant {
    // Need this check for safety because you could theoretically withdraw all funds right before a claim
    require(_amount == fundsRaised, "Pot: Amount claimed must equal input amount.");
    require(state == State.fundraising, "Pot: Pot must be in fundraising mode.");

    // Update state
    state = State.claimed;

    // Update reserve pricing
    votingShares = fundsRaised;
    reserveTotal = fundsRaised * fundsRaised;

    // Transfer the NFT
    if (standard == Standard.ERC721) {
      IERC721 UntrustedNFT = IERC721(nftAddress);
      require(UntrustedNFT.ownerOf(tokenID) == msg.sender, "Pot: NFT owner must be calling this function.");

      // Transfer NFT from seller to pot
      UntrustedNFT.safeTransferFrom(msg.sender, address(this), tokenID);
    } else {
      IERC1155 UntrustedNFT = IERC1155(nftAddress);
      require(UntrustedNFT.balanceOf(msg.sender, tokenID) >= 1, "Pot: NFT owner must be calling this function.");

      // Transfer NFT from seller to pot
      UntrustedNFT.safeTransferFrom(msg.sender, address(this), tokenID, 1, "");
    }

    if (PotluckSettings(settingsAddress).feeEnabled()) { // send fee to protocol
      feeCollected = getLiveSaleFee();
      (bool successFee,) = settingsAddress.call{ value: feeCollected }("");
      require(successFee, "Pot: Failed to send Ether to Potluck.");
    }

    // Send funds to the seller
    (bool success,) = msg.sender.call{ value: fundsRaised - feeCollected }("");
    require(success, "Pot: Failed to send Ether to seller.");

    emit PotContributionsClaimed(msg.sender);
  }

  // =============================================
  // ========== CLAIMED STATE FUNCTIONS ==========
  // =============================================

  /**
   * Contributor may set the reserve price they want for the NFT.
   */
  function setReservePrice(uint256 _price) external onlyContributor {
    require(state == State.claimed, "Pot: Pot must be in claimed state.");
    require(_price <= PotluckSettings(settingsAddress).maxReservePrice(), "Pot: Reserve price must not exceed the max.");

    uint256 oldPrice;
    if (hasSetReservePrice[msg.sender]) {
      oldPrice = reservePrices[msg.sender];
    } else {
      oldPrice = fundsRaised;
      hasSetReservePrice[msg.sender] = true;
    }

    require(_price != oldPrice, "Pot: Must send new price.");

    // Voting shares are equivalent to contribution amount
    uint256 shares = contributions[msg.sender].value;

    if (_price == 0) { // Removing their vote
      votingShares -= shares;
    } else if (oldPrice == 0) { // Adding their vote back in
      votingShares += shares;
    }

    reserveTotal -= (shares * oldPrice); // remove old vote value
    reserveTotal += (shares * _price); // add new vote value

    // Record new reserve price for this contributor
    reservePrices[msg.sender] = _price;

    emit PotReservePriceSet(msg.sender, _price);
  }

  /**
   * Someone can start an auction for the NFT by sending ETH that hits the reserve
   * price.
   */
  function startAuction() external payable {
    require(state == State.claimed, "Pot: Must be in claimed state.");
    require(msg.value >= reservePrice(), "Pot: Must send at least the reserve price.");

    // Update state
    state = State.auctioning;

    // Record bid
    Bid memory newBid = Bid(msg.sender, msg.value, block.timestamp);
    bids.push(newBid);

    // Set auction end time
    auctionEnd = block.timestamp + auctionDuration;

    emit PotAuctionStarted(msg.sender, msg.value, block.timestamp);
  }

  // ==========================================
  // ========== AUCTIONING FUNCTIONS ==========
  // ==========================================

  /**
   * Bidders can place a new bid that utilizes their refunds by sending additional
   * ether.
   */
  function bid(uint256 _amount) external payable {
    require(block.timestamp < auctionEnd, "Pot: Auction must be live.");
    require(state == State.auctioning, "Pot: Auction must be in auctioning state.");
    require(_amount >= minBid(), "Pot: Bid must be greater than the leading bid.");
    Bid memory previous = topBid();

    // Cases for a bid: new bidder, increasing bid, or bidder with existing refund
    // Topping up bid
    if (previous.bidder == msg.sender) {
      require(_amount == msg.value + previous.amount, "Pot: Ether sent must increment to bid amount.");
    } else {
      uint256 refund = refunds[msg.sender];
      if (refund > 0) { // has refund to utilize
        require(_amount == msg.value + refund, "Pot: Ether sent must increment to bid amount.");
        refunds[msg.sender] = 0;
      }  else { // new bid
        require(_amount == msg.value, "Pot: Ether sent must equal bid amount.");
      }

      // Record available refund for previous highest bidder
      refunds[previous.bidder] = previous.amount;
    }

    // Possibly extend auction deadline
    if (block.timestamp >= auctionEnd - extensionWindow) {
      auctionEnd += extensionDuration;
    }

    // Update highest bid
    Bid memory highest = Bid(msg.sender, _amount, block.timestamp);
    bids.push(highest);

    emit PotBid(msg.sender, _amount, block.timestamp);
  }

  /**
   * Bidders can withdraw their losing bids.
   */
  function claimRefund() external nonReentrant {
    uint256 refund = refunds[msg.sender];
    require(refund > 0, "Pot: Must have refund availble to claim.");

    // Nullify refund
    delete refunds[msg.sender];

    // Return funds
    (bool success,) = msg.sender.call{ value: refund }("");
    require(success, "Pot: Failed to send Ether.");

    emit PotRefundClaimed(msg.sender, refund);
  }

  /**
   * Someone may formally end the auction which will send the NFT to the winning
   * bidder.
   */
  function settleAuction() external {
    require(block.timestamp >= auctionEnd, "Pot: Auction must be over.");
    require(state == State.auctioning, "Pot: Auction must be in auctioning state.");

    // Update state
    state = State.settled;

    // Record proceeds to claim
    Bid memory winner = topBid();

    // Transfer NFT to winning bidder
    if (standard == Standard.ERC721) {
      IERC721 UntrustedNFT = IERC721(nftAddress);
      UntrustedNFT.safeTransferFrom(address(this), winner.bidder, tokenID);
    } else {
      IERC1155 UntrustedNFT = IERC1155(nftAddress);
      UntrustedNFT.safeTransferFrom(address(this), winner.bidder, tokenID, 1, "");
    }

    emit PotAuctionSettled(winner.bidder, winner.amount);
  }

  // ============================================
  // ========== POST AUCTION FUNCTIONS ==========
  // ============================================

  /**
   * Contributors can withdraw their share of the proceeds from selling the NFT.
   */
  function claimProceeds() external onlyContributor {
    require(state == State.settled, "Pot: Auction must be in end state.");

    bool claimed = contributions[msg.sender].proceedsClaimed;
    require(!claimed, "Pot: Must have not already claimed your proceeds.");

    // Nullify claim
    contributions[msg.sender].proceedsClaimed = true;

    // Retrieve amount
    uint256 proceeds = contributorProceeds(msg.sender);

    // Send proceeds
    (bool success,) = msg.sender.call{ value: proceeds }("");
    require(success, "Pot: Failed to send Ether.");

    emit PotProceedsClaimed(msg.sender, proceeds);
  }
}

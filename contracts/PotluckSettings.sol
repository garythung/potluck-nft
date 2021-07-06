// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.3;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PotluckSettings is Ownable {
  // =====================================
  // ========== MUTABLE STORAGE ==========
  // =====================================

  // How long auctions will run for
  uint256 public auctionDuration;
  // Minimum percentage that a new bid must beat the highest bid by
  uint256 public minBidDeltaPercentage;
  // Time before auction end in which a new bid will extend the auction end time
  uint256 public extensionWindow;
  // Time that an auction will be extended from a near closing bid
  uint256 public extensionDuration;
  // Max reserve price
  uint256 public maxReservePrice;
  // Safeguards turned on or off
  bool public safeguarded;
  // Max fundraising limit
  uint256 public maxFundraising;
  // Fee collection turned on or off
  bool public feeEnabled;
  // Fee basis points; a value of 100 = 1%
  uint256 public feeBasisPoints;

  // ============================
  // ========== EVENTS ==========
  // ============================

  // Min bid delta updated
  event BidDeltaChanged(uint256 prev, uint256 curr);
  // Auction duration updated
  event AuctionDurationChanged(uint256 prev, uint256 curr);
  // Extension window updated
  event ExtensionWindowChanged(uint256 prev, uint256 curr);
  // Extension duration updated
  event ExtensionDurationChanged(uint256 prev, uint256 curr);
  // Max reserve price updated
  event MaxReservePriceChanged(uint256 prev, uint256 curr);
  // Safeguards toggled
  event SafeguardsChanged(bool prev, bool curr);
  // Max fundraising limit updated
  event MaxFundraisingChanged(uint256 prev, uint256 curr);
  // Fee toggled
  event FeeEnabledChanged(bool prev, bool curr);
  // Fee percentage updated
  event FeeBasisPointsChanged(uint256 prev, uint256 curr);

  // =================================
  // ========== CONSTRUCTOR ==========
  // =================================

  constructor(
    uint256 _minBidDeltaPercentage,
    uint256 _auctionDuration,
    uint256 _extensionWindow,
    uint256 _extensionDuration,
    uint256 _maxReservePrice,
    uint256 _maxFundraising,
    uint256 _feeBasisPoints
  ) {
    minBidDeltaPercentage = _minBidDeltaPercentage;
    auctionDuration = _auctionDuration;
    extensionWindow = _extensionWindow;
    extensionDuration = _extensionDuration;
    maxReservePrice = _maxReservePrice;
    maxFundraising = _maxFundraising;
    feeBasisPoints = _feeBasisPoints;
    feeEnabled = true;
  }

  // ====================================
  // ========== EDIT FUNCTIONS ==========
  // ====================================

  function setBidDelta(uint256 _new) external onlyOwner {
    uint256 prev = minBidDeltaPercentage;
    minBidDeltaPercentage = _new;
    emit BidDeltaChanged(prev, _new);
  }

  function setAuctionDuration(uint256 _new) external onlyOwner {
    uint256 prev = auctionDuration;
    auctionDuration = _new;
    emit AuctionDurationChanged(prev, _new);
  }

  function setExtensionWindow(uint256 _new) external onlyOwner {
    uint256 prev = extensionWindow;
    extensionWindow = _new;
    emit ExtensionWindowChanged(prev, _new);
  }

  function setExtensionDuration(uint256 _new) external onlyOwner {
    uint256 prev = extensionDuration;
    extensionDuration = _new;
    emit ExtensionDurationChanged(prev, _new);
  }

  function setMaxReservePrice(uint256 _new) external onlyOwner {
    uint256 prev = maxReservePrice;
    maxReservePrice = _new;
    emit MaxReservePriceChanged(prev, _new);
  }

  function setSafeGuards(bool _new) external onlyOwner {
    bool prev = safeguarded;
    safeguarded = _new;
    emit SafeguardsChanged(prev, _new);
  }

  function setMaxFundraising(uint256 _new) external onlyOwner {
    uint256 prev = maxFundraising;
    maxFundraising = _new;
    emit MaxFundraisingChanged(prev, _new);
  }

  function setFeeEnabled(bool _new) external onlyOwner {
    bool prev = feeEnabled;
    feeEnabled = _new;
    emit FeeEnabledChanged(prev, _new);
  }

  function setFeeBasisPoints(uint256 _new) external onlyOwner {
    uint256 prev = feeBasisPoints;
    feeBasisPoints = _new;
    emit FeeBasisPointsChanged(prev, _new);
  }

  function sendFunds(address _recipient, uint256 _amount) external onlyOwner {
    (bool success,) = _recipient.call{ value: _amount }("");
    require(success, "Potluck Settings: Failed to send Ether.");
  }

  fallback() external payable {}
}

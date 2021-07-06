// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.3;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PotluckPot.sol";

contract PotluckFactory is Ownable {
  // =====================================
  // ========== MUTABLE STORAGE ==========
  // =====================================

  // Address of settings contract
  address payable public settingsAddress;
  // List of pots
  address[] public pots;
  // Mapping of pots
  mapping(address => bool) public potMapping;
  // Count of pots
  uint256 public numPots;

  // ============================
  // ========== EVENTS ==========
  // ============================

  // Details of a newly created pot
  event PotluckCreated(address pot);

  constructor(address payable _settingsAddress) {
    settingsAddress = _settingsAddress;
  }

  // ===========================
  // ========== VIEWS ==========
  // ===========================

  /**
   * List of pots
   */
  function potList() public view returns (address[] memory) {
    return pots;
  }

  /**
   * Pagination fetcher for an array of potluck addresses
   */
  function fetchPage(uint256 cursor, uint256 howMany) public view returns (address[] memory, uint256) {
    uint256 length = howMany;
    if (length > pots.length - cursor) {
      length = pots.length - cursor;
    }

    address[] memory values = new address[](length);
    for (uint256 i = 0; i < length; i++) {
      values[i] = pots[cursor + i];
    }

    return (values, cursor + length);
  }

  // ====================================
  // ========== EDIT FUNCTIONS ==========
  // ====================================

  function setSettings(address payable _newAddress) external onlyOwner {
    settingsAddress = _newAddress;
  }

  // ======================================
  // ========== CREATE FUNCTIONS ==========
  // ======================================

  function createPot(
    address _nftAddress,
    uint256 _tokenID,
    PotluckPot.Standard _standard
  ) external payable returns (address) {
    address potluck = address((new PotluckPot){ value: msg.value }(settingsAddress, msg.sender, _nftAddress, _tokenID, _standard));
    pots.push(potluck);
    potMapping[potluck] = true;
    emit PotluckCreated(potluck);
    return potluck;
  }
}

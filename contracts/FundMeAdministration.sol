// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";

error FundMeAdministrator__NotOwner();
error FundMeAdministrator__NotReceiver();

contract FundMeAdministrator {
    using PriceConverter for uint256;

    struct FundTransaction {
        address from;
        address to;
        address amount;
    }

    struct Receiver {
        address receiverAddress;
        string description;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert FundMeAdministrator__NotOwner();
        _;
    }

    modifier onlyReceiver() {
        Receiver[] memory receivers = s_receivers;
        if (receivers.length == 0) revert FundMeAdministrator__NotReceiver();

        bool isPresent = false;
        for (uint i = 0; i < receivers.length; i++) {
            address curAddress = receivers[i].receiverAddress;
            if (curAddress == msg.sender) {
                _;
                return;
            }
        }

        revert FundMeAdministrator__NotReceiver();
    }

    Receiver[] public s_receivers;
    mapping(address => uint256) public s_addressToAmountReceived;
    FundTransaction[] public s_fundTransactions;

    address private immutable i_owner;
    AggregatorV3Interface private immutable i_priceFeed;

    constructor(address priceFeedAddress) {
        i_owner = msg.sender;
        i_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }
}

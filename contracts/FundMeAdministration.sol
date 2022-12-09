// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";

error FundMeAdministrator__NotOwner();
error FundMeAdministrator__NotReceiver();
error FundMeAdministrator__NotMinimalFee();
error FundMeAdministrator__NotMinimalFund();
error FundMeAdministrator__AlreadyAReceiver();

contract FundMeAdministrator {
    using PriceConverter for uint256;

    struct FundTransaction {
        address from;
        address to;
        uint amount;
    }

    struct Receiver {
        address receiverAddress;
        string description;
    }

    modifier minimalFeeMet() {
        if (msg.value.getConversionRate(i_priceFeed) < MINIMAL_FEE)
            revert FundMeAdministrator__NotMinimalFee();
        _;
    }

    modifier minimalFundMet() {
        if (msg.value.getConversionRate(i_priceFeed) < MINIMAL_FUND)
            revert FundMeAdministrator__NotMinimalFund();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert FundMeAdministrator__NotOwner();
        _;
    }

    modifier notAReceiver() {
        Receiver[] memory receivers = s_receivers;

        bool isPresent = false;
        for (uint i = 0; i < receivers.length; i++) {
            address curAddress = receivers[i].receiverAddress;
            if (curAddress == msg.sender) {
                revert FundMeAdministrator__AlreadyAReceiver();
            }
        }
        _;
    }

    modifier onlyReceiver() {
        Receiver[] memory receivers = s_receivers;

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
    FundTransaction[] public s_notWithdrawnTransactions;

    address private immutable i_owner;
    AggregatorV3Interface private immutable i_priceFeed;
    uint public constant MINIMAL_FEE = 20;
    uint public constant MINIMAL_FUND = 5;

    constructor(address priceFeedAddress) {
        i_owner = msg.sender;
        i_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    function registerReceiver(
        string memory description
    ) public payable minimalFeeMet notAReceiver {
        Receiver memory newReceiver = Receiver(msg.sender, description);
        s_receivers.push(newReceiver);
    }

    function fund(address receiver) public payable minimalFundMet {
        FundTransaction memory newTransaction = FundTransaction(
            msg.sender,
            receiver,
            msg.value
        );

        s_notWithdrawnTransactions.push(newTransaction);
    }

    function withdrawToTheOwner() public onlyOwner {
        FundTransaction[]
            memory notWithdrawnTransactions = s_notWithdrawnTransactions;

        uint allEth = address(this).balance;
        uint receiversEth = 0;
        for (uint i = 0; i < notWithdrawnTransactions.length; i++) {
            receiversEth += notWithdrawnTransactions[i].amount;
        }

        uint ownerEth = allEth - receiversEth;
        (bool callSuccess, ) = payable(i_owner).call{value: ownerEth}("");
        require(callSuccess, "Call failed");
    }

    function withdrawToTheReceiver() public onlyReceiver {
        FundTransaction[]
            memory notWithdrawnTransactions = s_notWithdrawnTransactions;
        FundTransaction[] memory newTransactions = new FundTransaction[](0);
        Receiver[] memory receivers = s_receivers;
        Receiver[] memory newReceivers = new Receiver[](0);

        uint receiversFundingEth = 0;
        for (uint i = 0; i < notWithdrawnTransactions.length; i++) {
            if (msg.sender == notWithdrawnTransactions[i].to) {
                receiversFundingEth += notWithdrawnTransactions[i].amount;
            } else {
                newTransactions.push(notWithdrawnTransactions[i]);
            }
        }

        for (uint i = 0; i < receivers.length; i++) {
            if (receivers[i].receiverAddress != msg.sender) {
                newReceivers.push(receivers[i]);
            }
        }

        (bool callSuccess, ) = payable(msg.sender).call{
            value: receiversFundingEth
        }("");
        require(callSuccess, "Call failed");
    }
}

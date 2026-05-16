// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title    A simple lottery raffle contract
 * @author   Prince Chinedu
 * @notice   This contract does automatic lottery raffling of participats
 * @dev      Implements ChainVRFv2.5 rather than pseudo-randomness
 */

import {
    VRFConsumerBaseV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    // Your subscription ID.
    uint256 private immutable i_subscriptionId;

    // Sepolia coordinator. For other networks,
    // see https://docs.chain.link/vrf/v2-5/supported-networks#configurations
    /* vrf_sepolia address : 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B */

    address private immutable i_vrfCoordinator;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/vrf/v2-5/supported-networks#configurations
    bytes32 private immutable i_keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 40,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 private immutable i_callgaslimit;
    // The default is 3, but you can set this higher.
    uint16 private constant REQUEST_CONFIRMATIONS = 5;

    // For this example, retrieve 1 random value in one request.
    // Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
    uint32 private constant NUM_WORDS = 1;

    /* Custom Error */
    error Raffle__NotEnoughETHsent();
    error Raffle__NotYetTimeForLottery();
    error Raffle__NoParticipants();
    error Raffle__NoRandomWords();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    /* @dev for setting the amount the lottery requires */
    uint256 private immutable i_entrancefee;
    /* @dev for setting the interval for the lottery */
    uint256 private immutable i_interval;

    /*@ dev Storage variables */
    address payable[] private s_participants;
    uint256 private s_lasttimestamp;
    address private s_recentWinner;
    uint256 private s_lastRequestId;
    RaffleState private s_RaffleState;

    /* Type declaration */
    /* Custom Type */
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    /* Events used to log the acivities occuring on-chain */
    event RaffleEnter(address indexed participant);
    event RequestedRaffleNumber(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /** @dev constructor is only executed once when contract is deployed */

    constructor(
        uint256 entrancefee,
        uint256 interval,
        uint256 subscriptionId,
        address _vrfCoordinator,
        uint32 _callgaslimit,
        bytes32 _gaslane
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entrancefee = entrancefee;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_vrfCoordinator = _vrfCoordinator;
        /* s_lasttimestamp stores the time when the deploment occured */
        s_lasttimestamp = block.timestamp;
        s_RaffleState = RaffleState.OPEN;
        i_callgaslimit = _callgaslimit;
        i_keyHash = _gaslane;
    }

    /*//////////////////////////////////////////////////////////////
                          PLAYERS ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function enterlottery() public payable {
        if (msg.value < i_entrancefee) {
            revert Raffle__NotEnoughETHsent();
        }

        if (s_RaffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_participants.push(payable(msg.sender));

        emit RaffleEnter(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                     READY TO PICK A LOTTERY WINNER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev checkUpkeep checks if it's time to pick the winner
     * @notice This function is called by the upkeep system to determine if the raffle is ready to pick a winner
     */

    // the following needs to be true in order for the upkeepNeeded to be true;
    // 1. The time interval has reached or passed.
    // 2. The lottery is open
    // 3. There are participants in the lottery
    // 4. The contract has ETH
    // 5. Implicitly, subscription has LINK

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /*data */) {
        /* @notice All boolean values are set to true */
        bool timeHasPassed = (block.timestamp - s_lasttimestamp) >= i_interval;
        bool isRaffleOpen = (s_RaffleState == RaffleState.OPEN);
        bool hasbalance = address(this).balance > 0;
        bool hasplayers = s_participants.length > 0;

        upkeepNeeded =
            timeHasPassed &&
            isRaffleOpen &&
            hasbalance &&
            hasplayers;
        return (upkeepNeeded, "");
    }

    /*//////////////////////////////////////////////////////////////
                        RANDOM NUMBER SELECTION
    //////////////////////////////////////////////////////////////*/

    /* @dev here, the performUpkeep starts requesting for a random number if checkUpkeep is true */

    function performUpkeep(bytes calldata /* performData */) external {
        /* To check if the interval has passed */
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__NotYetTimeForLottery();
        }

        // Get a random number if time interval is greater or equal //
        // to the specified interval using CHAYINLINKVRF2.5//
        /*   */
        // What happens in the hood is.
        // a. Request Random Number Generator from VRF
        // b. Getting RNG from VRF via calldata

        /* RNG REQUEST! */
        s_RaffleState = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callgaslimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        s_lastRequestId = requestId;
        emit RequestedRaffleNumber(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                    CHOOSEN WINNER AND RAFFLE RESET
    //////////////////////////////////////////////////////////////*/

    function fulfillrandomword(
        uint256 /* requestId */,
        uint256[] calldata randomNumbers
    ) internal override {
        if (s_participants.length == 0) {
            revert Raffle__NoParticipants();
        }
        if (randomNumbers.length == 0) {
            revert Raffle__NoRandomWords();
        }
        // always going to pick the first random number from random array
        uint256 indexOfWinner = randomNumbers[0] % s_participants.length;
        address payable winner = s_participants[indexOfWinner];
        s_recentWinner = winner;
        s_participants = new address payable[](0);
        s_lasttimestamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        s_RaffleState = RaffleState.OPEN;
        emit WinnerPicked(winner);
    }

    // getter functions section
    function getEntranceFee() public view returns (uint256) {
        return i_entrancefee;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getSubscriptionId() public view returns (uint256) {
        return i_subscriptionId;
    }

    function getVRFCoordinator() public view returns (address) {
        return i_vrfCoordinator;
    }

    function lengthOfgetParticipants() public view returns (uint256) {
        return s_participants.length;
    }

    function getParticipant(uint256 index) public view returns (address) {
        return s_participants[index];
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_RaffleState;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLastRequestId() public view returns (uint256) {
        return s_lastRequestId;
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lasttimestamp;
    }
}

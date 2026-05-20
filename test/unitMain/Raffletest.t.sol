// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {
    VRFCoordinatorV2_5Mock
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {
    VRFConsumerBaseV2Plus
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

import {HelperConfig} from "script/HelperConfig.s.sol";

// helper contract used to force prize payout failure during winner transfer
// this gives us deterministic coverage for Raffle__TransferFailed.
contract RevertingWinner {
    function enterRaffle(Raffle raffle) external payable {
        raffle.enterlottery{value: msg.value}();
    }

    receive() external payable {
        revert("reject-eth");
    }
}

contract Raffletest is Test {
    Raffle internal raffle;
    VRFCoordinatorV2_5Mock internal vrfCoordinator;

    /* @dev makeAddr which creates mock test addresses */
    address internal PLAYER_ONE_ONE = makeAddr("PLAYER_ONEOne");
    address internal PLAYER_ONE_TWO = makeAddr("PLAYER_ONETwo");
    address internal PLAYER_ONE_THREE = makeAddr("PLAYER_ONEThree");

    /* Constant Variables */
    uint256 internal constant entranceFee = 0.02 ether;
    uint256 internal constant interval = 60;
    uint256 internal subId;
    uint32 internal constant callgaslimit = 200000;
    bytes32 internal gaslane = vm.envBytes32("KEY_HASH");
    uint256 internal constant STARTING_BALANCE = 5 ether;
    uint96 internal constant BASE_FEE = 1e9;
    uint96 internal constant GAS_PRICE_LINK = 1e9;
    int256 internal constant WEI_PER_UNIT_LINK = 1e18;
    uint256 internal constant FUND_AMOUNT = 100 ether;
    uint256 internal constant MAINNET_CHAIN_ID = 1;
    uint256 internal constant ANVIL_CHAIN_ID = 31337;
    uint256 internal constant INVALID_CHAIN_ID = 999999;

    /**
     * @dev setUp function to initialize the test environment
     * @dev This setUp functions oes the following:
     * 1. Creates a mock vrf contract address
     * 2. Create a mock subscription Id
     * 3. Deploys a new Raffle contract to set the Test Environment of its functions
     * 6. Funds each of the participants using vm.deal()
     */
    event RaffleEnter(address indexed participant);
    event RequestedRaffleNumber(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    receive() external payable {}
    fallback() external payable {}

    /*//////////////////////////////////////////////////////////////
                          TESTING USING MOCKS
    //////////////////////////////////////////////////////////////*/

    function setUp() external {
        // Use a fresh mock coordinator for deterministic unit tests.
        vrfCoordinator = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK);
        subId = vrfCoordinator.createSubscription();

        raffle = new Raffle(entranceFee, interval, subId, address(vrfCoordinator), callgaslimit, gaslane);
        vrfCoordinator.addConsumer(subId, address(raffle));
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        vm.deal(PLAYER_ONE_ONE, STARTING_BALANCE);
        vm.deal(PLAYER_ONE_TWO, STARTING_BALANCE);
        vm.deal(PLAYER_ONE_THREE, STARTING_BALANCE);
    }

    function testCheckUpkeepReturnsFalseWhenNoPLAYER_ONEsOrBalance() external {
        vm.warp(block.timestamp + interval + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenIntervalHasNotPassed() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1); // at this point it has not passed or reached
        vm.roll(block.timestamp);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenRaffleIsCalculating() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.timestamp + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);

        /* RaffleState.OPEN = 0
        /* RaffleState.CALCULATING = 1 */
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));
    }

    function testCheckUpkeepReturnsTrueWhenAllConditionsAreMet() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function testPerformUpkeepUpdatesStateAndStoresRequestId() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);

        raffle.performUpkeep("");

        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.CALCULATING));
        assertGt(raffle.getLastRequestId(), 0);
    }

    function testEnterLotteryRevertsWhenRaffleIsNotOpen() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();

        // move time forward so upkeep can transition the raffle into CALCULATING.
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.prank(PLAYER_ONE_TWO);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterlottery{value: entranceFee}();
    }

    function testRawFulfillRandomWordsRevertsIfNotCalledByCoordinator() external {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 123;

        vm.expectRevert(
            abi.encodeWithSelector(
                VRFConsumerBaseV2Plus.OnlyCoordinatorCanFulfill.selector, address(this), address(vrfCoordinator)
            )
        );
        raffle.rawFulfillRandomWords(1, randomWords);
    }

    function testFuzzFulfillRandomWordRevertsWhenWinnerTransferFails(uint256 seed) external {
        RevertingWinner revertingWinner = new RevertingWinner();
        vm.deal(address(revertingWinner), STARTING_BALANCE);
        revertingWinner.enterRaffle{value: entranceFee}(raffle);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;

        vm.prank(address(vrfCoordinator));
        vm.expectRevert(Raffle.Raffle__TransferFailed.selector);
        raffle.rawFulfillRandomWords(seed, randomWords);
    }

    function testWinnerReceivesExactPrizePoolFromAllEntranceFees() external {
        address playerFour = makeAddr("PLAYER_FOUR");
        vm.deal(playerFour, STARTING_BALANCE);

        address[] memory players = new address[](4);
        players[0] = PLAYER_ONE_ONE;
        players[1] = PLAYER_ONE_TWO;
        players[2] = PLAYER_ONE_THREE;
        players[3] = playerFour;

        for (uint256 i = 0; i < players.length; i++) {
            vm.prank(players[i]);
            raffle.enterlottery{value: entranceFee}();
        }

        uint256 expectedPrizePool = entranceFee * players.length;
        assertEq(address(raffle).balance, expectedPrizePool);

        vm.warp(block.timestamp + interval + 1);
        raffle.performUpkeep("");
        uint256 requestId = raffle.getLastRequestId();

        uint256[] memory forcedWords = new uint256[](1);
        forcedWords[0] = 2; // selects players[2] as winner when modded by 4.
        address expectedWinner = players[2];
        uint256 winnerBalanceAfterEntry = expectedWinner.balance;

        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(raffle), forcedWords);

        // gross payout must equal the full pool funded by all participants.
        assertEq(expectedWinner.balance - winnerBalanceAfterEntry, expectedPrizePool);
        // net profit must equal other participants' total entrance fees.
        assertEq(expectedWinner.balance - STARTING_BALANCE, entranceFee * (players.length - 1));
        assertEq(address(raffle).balance, 0);
        assertEq(raffle.getRecentWinner(), expectedWinner);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTING SECTION
    //////////////////////////////////////////////////////////////*/

    function testFuzzEnterLotteryRevertsWhenValueIsBelowEntranceFee(uint256 amount) external {
        // bound generated value so every fuzz case stays strictly below entrance fee.
        amount = bound(amount, 0, entranceFee - 1);

        vm.prank(PLAYER_ONE_ONE);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHsent.selector);
        raffle.enterlottery{value: amount}();
    }

    function testFuzzFulfillRandomWordRevertsWhenNoParticipants(uint256 requestId, uint256 randomWord) external {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        vm.prank(address(vrfCoordinator));
        vm.expectRevert(Raffle.Raffle__NoParticipants.selector);
        raffle.rawFulfillRandomWords(requestId, randomWords);
    }

    function testFuzzFulfillRandomWordRevertsWhenNoRandomWords(uint8 participantCount, uint256 requestId) external {
        participantCount = uint8(bound(participantCount, 1, 800));

        for (uint8 i = 0; i < participantCount; i++) {
            /* Creates a fake address ensuring every participant has a unique Address */
            address participant = makeAddr(string(abi.encodePacked("fuzz-no-words-", vm.toString(i))));
            vm.deal(participant, STARTING_BALANCE);
            vm.prank(participant);
            raffle.enterlottery{value: entranceFee}();
        }

        uint256[] memory randomWords = new uint256[](0);
        vm.prank(address(vrfCoordinator));
        vm.expectRevert(Raffle.Raffle__NoRandomWords.selector);
        raffle.rawFulfillRandomWords(requestId, randomWords);
    }

    function testFuzzFulfillRandomWordSelectsExpectedWinnerAndResetsState(
        uint8 participantCount,
        uint256 requestId,
        uint256 randomWord
    )
        external
    {
        participantCount = uint8(bound(participantCount, 1, 800));
        address[] memory participants = new address[](participantCount);

        for (uint8 i = 0; i < participantCount; i++) {
            // create deterministic participant accounts to keep expected winner math reproducible.
            address participant = makeAddr(string(abi.encodePacked("fuzz-participant-", vm.toString(i))));
            participants[i] = participant;
            vm.deal(participant, STARTING_BALANCE);
            vm.prank(participant);
            raffle.enterlottery{value: entranceFee}();
        }

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        uint256 expectedWinnerIndex = randomWord % participantCount;
        address expectedWinner = participants[expectedWinnerIndex];
        uint256 winnerBalanceBefore = expectedWinner.balance;
        uint256 potBefore = address(raffle).balance;
        uint256 timestampBefore = raffle.getLastTimestamp();

        vm.prank(address(vrfCoordinator));
        raffle.rawFulfillRandomWords(requestId, randomWords);

        assertEq(raffle.getRecentWinner(), expectedWinner);
        assertEq(raffle.lengthOfgetParticipants(), 0);
        assertEq(address(raffle).balance, 0);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertGe(raffle.getLastTimestamp(), timestampBefore);
        assertEq(expectedWinner.balance - winnerBalanceBefore, potBefore);
    }

    function testFuzzPerformUpkeepRevertsBeforeInterval(uint256 timeAdvance) external {
        // cover any random time prior to interval; upkeep must remain not needed.
        timeAdvance = bound(timeAdvance, 0, interval - 1);

        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + timeAdvance);

        vm.expectRevert(Raffle.Raffle__NotYetTimeForLottery.selector);
        raffle.performUpkeep("");
    }

    /*//////////////////////////////////////////////////////////////
                             TESTING EMITS
    //////////////////////////////////////////////////////////////*/

    function testEnterLotteryEmits() external {
        vm.prank(PLAYER_ONE_ONE);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
    }

    function testRequestedRaffleNumberEmits() external {
        vm.deal(PLAYER_ONE_ONE, STARTING_BALANCE);
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        /* @dev conditions it needs to meet for checkUpkeep to return true */
        vm.warp(block.timestamp + interval + 1);
        assertTrue(raffle.lengthOfgetParticipants() > 0);
        assertTrue(address(raffle).balance > 0);
        assertTrue(raffle.getRaffleState() == Raffle.RaffleState.OPEN);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RequestedRaffleNumber(1);

        raffle.performUpkeep("");
    }

    function testPickWinnerWithFulfillRandomWordsEmits() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        raffle.performUpkeep("");
        uint256 requestId = raffle.getLastRequestId();
        vm.expectEmit(true, false, false, false, address(raffle));
        emit WinnerPicked(PLAYER_ONE_ONE);
        vrfCoordinator.fulfillRandomWords(requestId, address(raffle));
    }

    function testReceiveFunctionRoutesFundsToEnterLottery() external {
        vm.prank(PLAYER_ONE_ONE);
        (bool success,) = address(raffle).call{value: entranceFee}("");

        assertTrue(success);
        assertEq(raffle.lengthOfgetParticipants(), 1);
        assertEq(raffle.getParticipant(0), PLAYER_ONE_ONE);
    }

    function testFallbackFunctionRoutesFundsToEnterLottery() external {
        vm.prank(PLAYER_ONE_ONE);
        // non-empty calldata triggers fallback(), which should still enter the raffle.
        (bool success,) = address(raffle).call{value: entranceFee}(hex"1234");

        assertTrue(success);
        assertEq(raffle.lengthOfgetParticipants(), 1);
        assertEq(raffle.getParticipant(0), PLAYER_ONE_ONE);
    }

    /*//////////////////////////////////////////////////////////////
                       TESTING RAFFLE CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testEntrancefee() external view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    function testInterval() external view {
        assertEq(raffle.getInterval(), interval);
    }

    function testSubscriptionId() external view {
        assertEq(raffle.getSubscriptionId(), subId);
    }

    /*//////////////////////////////////////////////////////////////
                        TESTING NETWORKVRFCONFIG
    //////////////////////////////////////////////////////////////*/

    function testgetSepoliaCoordinateVRFAdd() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.CoordinatorConfig memory sepoliaConfig = helperConfig.getSepoliaCoordinateAdd();
        address coordinator = sepoliaConfig.vrfCoordinator;

        Raffle localRaffle = new Raffle(entranceFee, interval, subId, coordinator, callgaslimit, gaslane);

        assertEq(localRaffle.getVRFCoordinator(), coordinator);
    }

    function testgetMainnetCoordinateVRFAdd() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.CoordinatorConfig memory mainnetConfig = helperConfig.getMainnetCoordinateAdd();
        address coordinator = mainnetConfig.vrfCoordinator;

        Raffle localRaffle = new Raffle(entranceFee, interval, subId, coordinator, callgaslimit, gaslane);

        assertEq(localRaffle.getVRFCoordinator(), coordinator);
    }

    function testgetAnvilCoordinateVRFAdd() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.CoordinatorConfig memory anvilConfig = helperConfig.getAnvilCoordinateAdd();
        address coordinator = anvilConfig.vrfCoordinator;

        Raffle localRaffle = new Raffle(entranceFee, interval, subId, coordinator, callgaslimit, gaslane);

        assertEq(localRaffle.getVRFCoordinator(), coordinator);
    }

    /*//////////////////////////////////////////////////////////////
                   TESTING HELPERCONFIG CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/

    function testHelperConfigConstructorUsesMainnetPath() external {
        // simulate deployment on Ethereum mainnet so constructor selects mainnet branch.
        vm.chainId(MAINNET_CHAIN_ID);
        HelperConfig helperConfig = new HelperConfig();

        (address activeCoordinator) = helperConfig.activeNetworkConfig();
        HelperConfig.CoordinatorConfig memory mainnetConfig = helperConfig.getMainnetCoordinateAdd();
        assertEq(activeCoordinator, mainnetConfig.vrfCoordinator);
    }

    function testHelperConfigConstructorUsesAnvilPathAndDeploysMock() external {
        vm.chainId(ANVIL_CHAIN_ID);
        HelperConfig helperConfig = new HelperConfig();

        (address activeCoordinator) = helperConfig.activeNetworkConfig();
        assertTrue(activeCoordinator != address(0));
        // non-zero bytecode proves the mock coordinator was deployed in getAnvilCoordinateAdd().
        assertGt(activeCoordinator.code.length, 0);
    }

    function testHelperConfigConstructorRevertsOnUnsupportedChainId() external {
        vm.chainId(INVALID_CHAIN_ID);
        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainId.selector);
        new HelperConfig();
    }


    /*//////////////////////////////////////////////////////////////
                   TESTING ENTERLOTTERY PARTICIPATION
    //////////////////////////////////////////////////////////////*/

}

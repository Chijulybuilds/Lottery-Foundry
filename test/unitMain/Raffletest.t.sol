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

contract Raffletest is Test {
    Raffle internal raffle;
    VRFCoordinatorV2_5Mock internal vrfCoordinator;

    /* @dev makeAddr which creates mock test addresses */
    address internal PLAYER_ONE_ONE = makeAddr("PLAYER_ONEOne");
    address internal PLAYER_ONE_TWO = makeAddr("PLAYER_ONETwo");
    address internal PLAYER_ONE_THREE = makeAddr("PLAYER_ONEThree");

    /* Constant Variables */
    uint256 internal constant entranceFee = 0.2 ether;
    uint256 internal constant interval = 60;
    uint256 internal subId;
    uint32 internal constant callgaslimit = 40000;
    bytes32 internal gaslane = vm.envBytes32("KEY_HASH");
    uint256 internal constant STARTING_BALANCE = 5 ether;
    uint96 internal constant BASE_FEE = 1e9;
    uint96 internal constant GAS_PRICE_LINK = 1e9;
    int256 internal constant WEI_PER_UNIT_LINK = 1e18;
    uint256 internal constant FUND_AMOUNT = 100 ether;

    /** @dev setUp function to initialize the test environment 
    * @dev This setUp functions oes the following:
    1. Creates a mock vrf contract address
    2. Create a mock subscription Id
    3. Deploys a new Raffle contract to set the Test Environment of its functions
    6. Funds each of the participants using vm.deal()
    */
    event RaffleEnter(address indexed participant);
    event RequestedRaffleNumber(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /*//////////////////////////////////////////////////////////////
                          TESTING USING MOCKS
    //////////////////////////////////////////////////////////////*/

    function setUp() external {
        // Always use a fresh local mock for unit tests so behavior is deterministic
        // on local Anvil and on forked networks.
        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_PRICE_LINK,
            WEI_PER_UNIT_LINK
        );

        subId = vrfCoordinator.createSubscription();

        raffle = new Raffle(
            entranceFee,
            interval,
            subId,
            address(vrfCoordinator),
            callgaslimit,
            gaslane
        );

        vrfCoordinator.addConsumer(subId, address(raffle));
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        vm.deal(PLAYER_ONE_ONE, STARTING_BALANCE);
        vm.deal(PLAYER_ONE_TWO, STARTING_BALANCE);
        vm.deal(PLAYER_ONE_THREE, STARTING_BALANCE);
    }

    function testCheckUpkeepReturnsFalseWhenNoPLAYER_ONEsOrBalance() external {
        vm.warp(block.timestamp + interval + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testRevertsIfOnePLAYER_ONEDoesNotSendEnoughETH() external {
        vm.prank(PLAYER_ONE_ONE);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHsent.selector);
        raffle.enterlottery{value: entranceFee - 1}();
    }

    function testCheckUpkeepReturnsFalseWhenIntervalHasNotPassed() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1); // at this point it has not passed or reached
        vm.roll(block.timestamp);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenRaffleIsCalculating() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.timestamp + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);

        /* RaffleState.OPEN = 0
        /* RaffleState.CALCULATING = 1 */
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.CALCULATING)
        );
    }

    function testCheckUpkeepReturnsTrueWhenAllConditionsAreMet() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function testPerformUpkeepRevertsWhenCheckUpkeepIsFalse() external {
        vm.expectRevert(Raffle.Raffle__NotYetTimeForLottery.selector);
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesStateAndStoresRequestId() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);

        raffle.performUpkeep("");

        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.CALCULATING)
        );
        assertGt(raffle.getLastRequestId(), 0);
    }

    function testRawFulfillRandomWordsRevertsIfNotCalledByCoordinator()
        external
    {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 123;

        vm.expectRevert(
            abi.encodeWithSelector(
                VRFConsumerBaseV2Plus.OnlyCoordinatorCanFulfill.selector,
                address(this),
                address(vrfCoordinator)
            )
        );
        raffle.rawFulfillRandomWords(1, randomWords);
    }

    function testFulfillRandomWordPicksWinnerResetsAndPaysPrize() external {
        address[] memory PLAYER_ONEs = new address[](3);
        uint256 PLAYER_ONE_length = PLAYER_ONEs.length;
        PLAYER_ONEs[0] = PLAYER_ONE_ONE;
        PLAYER_ONEs[1] = PLAYER_ONE_TWO;
        PLAYER_ONEs[2] = PLAYER_ONE_THREE;

        for (uint256 i = 0; i < PLAYER_ONE_length; i++) {
            vm.prank(PLAYER_ONEs[i]);
            raffle.enterlottery{value: entranceFee}();
        }

        uint256 startingTimestamp = raffle.getLastTimestamp();
        vm.warp(block.timestamp + interval + 1); //has began lottery

        raffle.performUpkeep("");
        uint256 requestId = raffle.getLastRequestId();

        uint256 expectedWinnerIndex = uint256(
            keccak256(abi.encode(requestId, uint256(0)))
        ) % PLAYER_ONEs.length;
        address expectedWinner = PLAYER_ONEs[expectedWinnerIndex];
        uint256 winnerBalanceBefore = expectedWinner.balance;
        uint256 potBefore = address(raffle).balance;

        vrfCoordinator.fulfillRandomWords(requestId, address(raffle));

        assertEq(raffle.getRecentWinner(), expectedWinner);
        assertEq(raffle.lengthOfgetParticipants(), 0);
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.OPEN)
        );
        assertGt(raffle.getLastTimestamp(), startingTimestamp);
        assertEq(expectedWinner.balance - winnerBalanceBefore, potBefore);
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

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
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
        HelperConfig.CoordinatorConfig memory sepoliaConfig = helperConfig
            .getSepoliaCoordinateAdd();
        address coordinator = sepoliaConfig.vrfCoordinator;

        Raffle localRaffle = new Raffle(
            entranceFee,
            interval,
            subId,
            coordinator,
            callgaslimit,
            gaslane
        );

        assertEq(localRaffle.getVRFCoordinator(), coordinator);
    }

    function testgetMainnetCoordinateVRFAdd() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.CoordinatorConfig memory mainnetConfig = helperConfig
            .getMainnetCoordinateAdd();
        address coordinator = mainnetConfig.vrfCoordinator;

        Raffle localRaffle = new Raffle(
            entranceFee,
            interval,
            subId,
            coordinator,
            callgaslimit,
            gaslane
        );

        assertEq(localRaffle.getVRFCoordinator(), coordinator);
    }

    function testgetAnvilCoordinateVRFAdd() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.CoordinatorConfig memory anvilConfig = helperConfig
            .getAnvilCoordinateAdd();
        address coordinator = anvilConfig.vrfCoordinator;

        Raffle localRaffle = new Raffle(
            entranceFee,
            interval,
            subId,
            coordinator,
            callgaslimit,
            gaslane
        );

        assertEq(localRaffle.getVRFCoordinator(), coordinator);
    }

    /*//////////////////////////////////////////////////////////////
                   TESTING ENTERLOTTERY PARTICIPATION
    //////////////////////////////////////////////////////////////*/

    function testEnterlotteryParticipants() external {
        vm.prank(PLAYER_ONE_ONE);
        raffle.enterlottery{value: entranceFee}();

        /* Tests the entire array if there are players */
        assertGt(raffle.lengthOfgetParticipants(), 0);
        /* Tests if there is a player in the Array */
        assertEq(raffle.getParticipant(0), PLAYER_ONE_ONE);
    }
}

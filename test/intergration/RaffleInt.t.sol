// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {FundRaffle} from "script/Transactions.s.sol";
import {
    VRFCoordinatorV2_5Mock
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/*//////////////////////////////////////////////////////////////
                  TESTING ENTERLOTTERY PAYMENT
//////////////////////////////////////////////////////////////*/

contract RaffleInt is Test {
    Raffle internal raffle;
    FundRaffle internal fundRaffle;

    address internal USER = makeAddr("user");
    uint256 internal constant SEND_VALUE = 1 ether;
    uint256 internal constant ENTRY_FEE = 0.02 ether;
    uint256 internal constant INTERVAL = 60;
    uint32 internal constant CALLBACK_GAS_LIMIT = 40000;
    uint96 internal constant BASE_FEE = 1e9;
    uint96 internal constant GAS_PRICE_LINK = 1e9;
    int256 internal constant WEI_PER_UNIT_LINK = 1e18;

    uint256 internal constant SEPOLIA_ID = 11155111;
    uint256 internal constant MAINNET_ID = 1;
    uint256 internal constant ANVIL_ID = 31337;

    function setUp() external {
        if (block.chainid == 31337) {
            /* Anvil Blockchain Id */
            VRFCoordinatorV2_5Mock vrfcoordinator =
                new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK);
            uint256 subId = vrfcoordinator.createSubscription();
            raffle = new Raffle(
                ENTRY_FEE, INTERVAL, subId, address(vrfcoordinator), CALLBACK_GAS_LIMIT, vm.envBytes32("KEY_HASH")
            );
            vrfcoordinator.addConsumer(subId, address(raffle));
            vrfcoordinator.fundSubscription(subId, 100 ether);
        } else {
            DeployRaffle deployraffle = new DeployRaffle();
            raffle = deployraffle.run();
        }

        fundRaffle = new FundRaffle();
        vm.deal(USER, SEND_VALUE);
    }

    function testUsersCanFundInteractions() external {
        vm.setEnv("SEND_FEE_WEI", vm.toString(ENTRY_FEE));
        vm.deal(address(this), SEND_VALUE);
        fundRaffle.fundRaffle(address(raffle));

        assertEq(raffle.lengthOfgetParticipants(), 1);
        assertTrue(raffle.getParticipant(0) != address(0));
    }

    // function testGetMostRecentDeployWorksOnAllForks() external view {
    //     if (block.chainid != MAINNET_ID && block.chainid != SEPOLIA_ID && block.chainid != ANVIL_ID) {
    //         return; // skip unsupported/no-artifact networks like local anvil
    //     }

    //     address mostRecent = DevOpsTools.get_most_recent_deployment(
    //         "Raffle",
    //         block.chainid
    //     );
    //     assertTrue(mostRecent != address(0));
    // }
}

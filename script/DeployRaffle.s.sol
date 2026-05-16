// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title    A simple lottery raffle contract
 * @author   Prince Chinedu
 * @notice   This contract does the deploy of our raffle contract!!
 * @dev      Implements HelperConfig and .env source files getting new Raffle deployement
*/

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/*//////////////////////////////////////////////////////////////
                        DEPLOYMENT OF RAFFLE
//////////////////////////////////////////////////////////////*/

contract DeployRaffle is Script {
    uint256 internal entranceFee = 0.2 ether;
    uint256 internal interval = vm.envUint("INTERVAL");
    uint256 internal subId = vm.envUint("SUBSCRIPTION_ID");
    uint32 internal callgaslimit = uint32(vm.envUint("CALL_GAS_LIMIT"));
    bytes32 internal gaslane = vm.envBytes32("KEY_HASH");

    function run() external returns (Raffle) {
        HelperConfig helperConfig = new HelperConfig();
        (address vrfCoordinator) = helperConfig.activeNetworkConfig();
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            subId,
            address(vrfCoordinator),
            callgaslimit,
            gaslane
        );
        vm.stopBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, address(raffle));
        return raffle;
    }
}

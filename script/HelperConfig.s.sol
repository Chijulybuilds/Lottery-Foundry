//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/** 
* @title HelperConfig
* @notice This contract is used to configure the helper settings for different networks
* @author Prince_Chinedu
* @dev This contract is used to configure the helper settings for different networks
*/

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/* @dev This contract is used to configure the helper settings for different networks */

contract HelperConfig is Script {

    // The goal is if we are on a getAnvilConfig, then deploy mocks
    // else use the existing address to get live data for that chain
    error HelperConfig__InvalidChainId();
    // uint8 public constant DECIMALS = 8;
    // int256 public constant INITIAL_PRICE = 2000e8;
    uint256 public constant SEPOLIA_ID = 11155111;
    uint256 public constant MAINNET_ID = 1;
    uint256 public constant ANVIL_ID = 31337;
    uint96 public immutable i_base_fee = 1e9;
    uint96 public immutable i_gas_price = 1e9;
    int256 public immutable i_wei_per_unit_link = 1e18;

    struct CoordinatorConfig {
        address vrfCoordinator;
    }

    CoordinatorConfig public activeNetworkConfig;

    constructor () {
        if (block.chainid == SEPOLIA_ID) {
            activeNetworkConfig = getSepoliaCoordinateAdd();
        } else if (block.chainid == MAINNET_ID) {
            activeNetworkConfig = getMainnetCoordinateAdd();
        } else if (block.chainid == ANVIL_ID) {
            activeNetworkConfig = getAnvilCoordinateAdd();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaCoordinateAdd() public pure returns (CoordinatorConfig memory) {
        CoordinatorConfig memory sepoliaconfig = CoordinatorConfig({
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B});
        return sepoliaconfig;  
    }

    function getMainnetCoordinateAdd() public pure returns (CoordinatorConfig memory) {
        CoordinatorConfig memory mainnetconfig = CoordinatorConfig({
            vrfCoordinator: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a});
        return mainnetconfig;
    }

    // function getZkSyncSepoCoordinateAdd() public pure returns (CoordinatorConfig memory) {
    //     CoordinatorConfig memory zksyncSepoconfig = CoordinatorConfig({
    //         vrfCoordinator: 0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF});
    //     return zksyncSepoconfig;
    // }

    // function getZkSyncETHCoordinateAdd() public pure returns (CoordinatorConfig memory) {
    //     CoordinatorConfig memory zksyncConfig = CoordinatorConfig({
    //         vrfCoordinator: 0x6D41d1dc818112880b40e26BD6FD347E41008eDA});
    //     return zksyncConfig;
    // }

    function getAnvilCoordinateAdd() public returns (CoordinatorConfig memory) {
        /* @dev checking to see if we set an active network config */
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock mockvrfcoordinator = new VRFCoordinatorV2_5Mock(i_base_fee, i_gas_price, i_wei_per_unit_link);
        vm.stopBroadcast();

        CoordinatorConfig memory anvilconfig = CoordinatorConfig({vrfCoordinator: address(mockvrfcoordinator)});
        return anvilconfig;

    }
}

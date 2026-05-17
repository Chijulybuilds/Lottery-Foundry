// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title    Interaction contract for entering lottery
 * @author   Prince Chinedu
 * @notice   This contract is called for sending eth to lottery
 * @dev      Uses forge script
 */

import {Script} from "forge-std/Script.sol";
// DevOps used for identifying the most recently deployed address
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "src/Raffle.sol";

error Raffle__NotEnoughETHToEnterLottery();

/*//////////////////////////////////////////////////////////////
                      ENTERLOTTERY PAYMENT
//////////////////////////////////////////////////////////////*/
contract FundRaffle is Script {
    uint256 internal entranceFee = 20000000000000000 wei;

    function fundRaffle(address mostRecentDeploy) public {
        uint256 sendFeeWei = vm.envUint("SEND_FEE_WEI");
        if (sendFeeWei < entranceFee) {
            revert Raffle__NotEnoughETHToEnterLottery();
        }
        vm.startBroadcast();
        Raffle(payable(mostRecentDeploy)).enterlottery{value: sendFeeWei}();
        vm.stopBroadcast();
    }

    function run() external {
        // we need to get most recently deployed contract to interact with
        address mostRecentDeploy = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        fundRaffle(mostRecentDeploy);
    }
}

// contract WithdrawFundMe is Script {
//     function withdrawFundMe(address mostRecentDeploy) public {
//         vm.startBroadcast();
//         Raffle(payable(mostRecentDeploy)).withdraw();
//         vm.stopBroadcast();

//     }

//     function run() external {
//         address mostRecentDeploy = DevOpsTools.get_most_recent_deployment(
//             "FundMe",
//             block.chainid
//         );
//         withdrawFundMe(mostRecentDeploy);
//     }
// }

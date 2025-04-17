// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscriptions, FundSubscriptions, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //local => deploy mocks, get local config
        //sepolia => get sepolia config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        if (networkConfig.subscriptionID == 0) {
            //create subscription
            CreateSubscriptions subscription = new CreateSubscriptions();
            (networkConfig.subscriptionID, networkConfig.vrfCoordinator) =
                subscription.createSubscription(networkConfig.vrfCoordinator);

            //Funding the subscription
            FundSubscriptions fundSubscriptions = new FundSubscriptions();
            fundSubscriptions.fundSubscription(networkConfig.vrfCoordinator, networkConfig.subscriptionID, networkConfig.link);
        }
        vm.startBroadcast();
        Raffle raffle = new Raffle({
            _entranceFee: networkConfig.entranceFee,
            interval: networkConfig.interval,
            subscriptionID: networkConfig.subscriptionID,
            gasLane: networkConfig.gasLane,
            vrfCoordinator: networkConfig.vrfCoordinator,
            callbackGasLimit: networkConfig.callbackGasLimit
        });
        vm.stopBroadcast();
        
        //Add consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(networkConfig.vrfCoordinator, networkConfig.subscriptionID, address(raffle));

        return (raffle, helperConfig);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() external {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //local => deploy mocks, get local config
        //sepolia => get sepolia config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
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
        return (raffle, helperConfig);
    }
}

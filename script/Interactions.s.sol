// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {Raffle} from "src/Raffle.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @title Creating dynamic subscriptions
 * @author
 * @notice
 */
contract CreateSubscriptions is Script {
    function run() external {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256 subId, address) {
        console.log("Creating a new subscription id on chain: ", block.chainid);
        vm.startBroadcast();
        subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription id is: ", subId);
        return (subId, vrfCoordinator);
    }
}

contract FundSubscriptions is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; //3 LINK

    function run() external {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint256 subscriptionID = config.getConfig().subscriptionID;
        address linkToken = config.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionID, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionID, address linkToken) public {
        console.log("funding subscription: ", subscriptionID, "VRF Coordinator: ", vrfCoordinator);
        console.log("On-chain ID: ", block.chainid);

        if (block.chainid == LOCAL_CHAINID) {
            vm.startBroadcast();
            // LinkToken(linkToken).mint(address(this), FUND_AMOUNT);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionID, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionID));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address contractAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        Raffle raffle = Raffle(contractAddress);
        addConsumerUsingConfig(address(raffle));
    }

    function addConsumerUsingConfig(address consumer) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionID = helperConfig.getConfig().subscriptionID;

        addConsumer(vrfCoordinator, subscriptionID, consumer);
    }

    function addConsumer(address vrfCoordinator, uint256 subscriptionID, address consumer) public {
        console.log("Adding consumer to VRF Coordinator: ", vrfCoordinator);
        console.log("subscriptionID: ", subscriptionID);
        console.log("Consumer to add subscription for: ", consumer);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionID, consumer);
        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
//uint
//integrations
//forked
//staging <- run tests on a mainnet or testnet

//fuzzing
//stateful fuzz
//stateless fuzz
//formal verification
import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract InteractionTest is Test {
    Raffle raffle;
    HelperConfig config;
    address USER = makeAddr("alice");
    uint256 constant STARTING_BALANCE = 1e18;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, config) = deployRaffle.run();
        hoax(USER, STARTING_BALANCE);
    }

    function test_EnterRaffle() external {
        uint256 entranceFee = config.getConfig().entranceFee;
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayersArray().length, 1);
        assertEq(USER.balance, STARTING_BALANCE - entranceFee);
    }
    /**
     * @dev check if the raffle contract has been added as a consumer contract in VRF coordinator contract
     */
    function test_IfConsumerIsAdded() external {
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint256 subscriptionId = config.getConfig().subscriptionID;
        bool isActive = VRFCoordinatorV2_5Mock(vrfCoordinator).consumerIsAdded(subscriptionId, address(raffle));
        assertEq(isActive, true);
    }

    function test_ConsumerAddedIsRaffleContract() external {
        //Arrange
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint256 subscriptionId = config.getConfig().subscriptionID;
        //Act
        (,,,, address[] memory consumers) = VRFCoordinatorV2_5Mock(vrfCoordinator).getSubscription(subscriptionId);
        //Assert
        assertEq(consumers.length, 1);
        assertEq(consumers[0], address(raffle));
    }
}

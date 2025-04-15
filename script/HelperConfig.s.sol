// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    /**
     * VRF Mock Values
     */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant SEPOLIA_ETH_CHAINID = 11155111;
    uint256 public constant LOCAL_CHAINID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        uint256 subscriptionID;
        bytes32 gasLane;
        address vrfCoordinator;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        if (block.chainid == SEPOLIA_ETH_CHAINID) {
            networkConfigs[block.chainid] = getSepoliaETH();
        }
    }

    function getConfigByChainId(uint256 chainId) internal returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) return networkConfigs[block.chainid];
        else if (chainId == LOCAL_CHAINID) return getOrCreateAnvilEthConfig();
        else revert HelperConfig__InvalidChainId();
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaETH() internal pure returns (NetworkConfig memory sepoliaConfig) {
        sepoliaConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, //30 seconds
            subscriptionID: 11873126903611734121339298938978806608537751483402618870361079611777575397382,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            callbackGasLimit: 500000, //500,000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvilEthConfig() internal returns (NetworkConfig memory anvilNewtorkConfig) {
        if (localNetworkConfig.vrfCoordinator != address(0)) return localNetworkConfig;
        //Deploy mock contract as such
        //uint96 _baseFee, uint96 _gasPrice, int256 _weiPerUnitLink
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfMockContract =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UINT_LINK);
        LinkToken linktoken = new LinkToken();
        vm.stopBroadcast();
        anvilNewtorkConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, //30 seconds
            subscriptionID: 0,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            vrfCoordinator: address(vrfMockContract),
            callbackGasLimit: 500000,
            link: address(linktoken)
        });
        localNetworkConfig = anvilNewtorkConfig;
    }
}

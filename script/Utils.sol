// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {Test} from "forge-std/Test.sol";
import {IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";

import {IMaciVoting} from "../src/IMaciVoting.sol";
import {GovernanceERC20} from "../src/ERC20Votes/GovernanceERC20.sol";

library Utils {
    // the canonical hevm cheat‑code address
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function readMaciAddresses()
        public
        view
        returns (
            address maci,
            DomainObjs.PublicKey memory pk,
            IMaciVoting.VotingSettings memory vs,
            address verifier,
            address vkRegistry,
            address policyFactory,
            address checkerFactory,
            address voiceCreditProxyFactory
        )
    {
        maci = vm.envAddress("MACI_ADDRESS");
        verifier = vm.envAddress("VERIFIER_ADDRESS");
        vkRegistry = vm.envAddress("VK_REGISTRY_ADDRESS");
        policyFactory = vm.envAddress("POLICY_FACTORY_ADDRESS");
        checkerFactory = vm.envAddress("CHECKER_FACTORY_ADDRESS");
        voiceCreditProxyFactory = vm.envAddress("VOICE_CREDIT_PROXY_FACTORY_ADDRESS");
        pk = DomainObjs.PublicKey({
            x: vm.envUint("COORDINATOR_PUBLIC_KEY_X"),
            y: vm.envUint("COORDINATOR_PUBLIC_KEY_Y")
        });
        vs = IMaciVoting.VotingSettings(0, 0, 1);
    }

    function getGovernanceTokenAndMintSettings()
        public
        returns (
            GovernanceERC20,
            GovernanceERC20.TokenSettings memory,
            GovernanceERC20.MintSettings memory
        )
    {
        GovernanceERC20.TokenSettings memory tokenSettings = GovernanceERC20.TokenSettings({
            name: "DAO Voting Token",
            symbol: "DVT"
        });
        GovernanceERC20.MintSettings memory mintSettings = GovernanceERC20.MintSettings({
            receivers: new address[](3),
            amounts: new uint256[](3)
        });
        // local tests
        mintSettings.receivers[0] = address(0xB0b);
        mintSettings.amounts[0] = 1 * 10 ** 18;
        // Nico's address for UI tests
        mintSettings.receivers[1] = address(0xE4721A80C6e56f4ebeed6acEE91b3ee715e7dD64);
        mintSettings.amounts[1] = 5 * 10 ** 18;
        // John's address for UI tests
        mintSettings.receivers[2] = address(0x91AdDB0E8443C83bAf2aDa6B8157B38f814F0bcC);
        mintSettings.amounts[2] = 5 * 10 ** 18;

        GovernanceERC20 tokenToClone = new GovernanceERC20(
            IDAO(address(0x0)),
            tokenSettings.name,
            tokenSettings.symbol,
            mintSettings
        );
        return (tokenToClone, tokenSettings, mintSettings);
    }
}

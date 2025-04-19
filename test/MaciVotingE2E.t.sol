// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {DaoUnauthorized} from "@aragon/osx/core/utils/auth.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";

import {AragonE2E} from "./base/AragonE2E.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";
import {MaciVoting} from "../src/MaciVoting.sol";
import {IMaciVoting} from "../src/IMaciVoting.sol";
import {GovernanceERC20} from "../src/ERC20Votes/GovernanceERC20.sol";

contract MaciVotingE2E is AragonE2E {
    DAO internal dao;
    MaciVoting internal plugin;
    PluginRepo internal repo;
    MaciVotingSetup internal setup;
    address internal unauthorised = account("unauthorised");

    address internal maciAddress;
    DomainObjs.PublicKey internal coordinatorPublicKey;
    IMaciVoting.VotingSettings internal votingSettings;
    address internal verifier;
    address internal vkRegistry;
    address internal policyFactory;
    address internal checkerFactory;
    address internal voiceCreditProxyFactory;

    function setUp() public virtual override {
        super.setUp();

        GovernanceERC20 tokenToClone = new GovernanceERC20(
            IDAO(address(0x0)),
            "DAO Voting Token",
            "DVT",
            GovernanceERC20.MintSettings({receivers: new address[](0), amounts: new uint256[](0)})
        );

        GovernanceERC20.TokenSettings memory tokenSettings = GovernanceERC20.TokenSettings({
            name: "DAO Voting Token",
            symbol: "DVT"
        });
        GovernanceERC20.MintSettings memory mintSettings = GovernanceERC20.MintSettings({
            receivers: new address[](0),
            amounts: new uint256[](0)
        });

        setup = new MaciVotingSetup(tokenToClone);
        address _plugin;

        MaciVotingSetup.SetupMACIParams memory setupMaciParams = MaciVotingSetup.SetupMACIParams({
            maci: maciAddress,
            publicKey: coordinatorPublicKey,
            votingSettings: votingSettings,
            verifier: verifier,
            vkRegistry: vkRegistry,
            policyFactory: policyFactory,
            checkerFactory: checkerFactory,
            voiceCreditProxyFactory: voiceCreditProxyFactory
        });

        (dao, repo, _plugin) = deployRepoAndDao(
            "maciVotingTest",
            address(setup),
            abi.encode(setupMaciParams, tokenSettings, mintSettings)
        );

        plugin = MaciVoting(_plugin);
    }

    function test_e2e() public {
        // test repo
        PluginRepo.Version memory version = repo.getLatestVersion(repo.latestRelease());
        assertEq(version.pluginSetup, address(setup));
        assertEq(version.buildMetadata, NON_EMPTY_BYTES);

        // test dao
        assertEq(keccak256(bytes(dao.daoURI())), keccak256(bytes("https://mockDaoURL.com")));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract VestingWallet is Ownable, ReentrancyGuard {
    struct VestingSchedule {
        uint256 creationTime;
        uint256 cliff;
        uint256 duration;
        uint256 totalAmount;
        uint256 releasedAmount;
    }

    struct LogEntry {
        uint256 accessTime;
        address userAddress;
    }

    IERC20 public immutable _TOKEN;
    mapping(address => VestingSchedule) public vestingSchedules;
    LogEntry[] private accessLog;

    constructor(address tokenAddress) Ownable(msg.sender) {
        _TOKEN = IERC20(tokenAddress);
    }

    function logAccess() private {
        accessLog.push(LogEntry({accessTime: block.timestamp, userAddress: msg.sender}));
    }

    function checkAccessLog() public {
        for (uint256 i = 0; i < accessLog.length; ++i) {
            console.log(string.concat());
        }
    }

    function viewVestingSchedules(address beneficiary) public returns (VestingSchedule memory) {
        logAccess();
        return vestingSchedules[beneficiary];
    }

    function createVestingSchedule(address beneficiary, uint256 totalAmount, uint256 cliff, uint256 duration)
        public
        onlyOwner
    {
        logAccess();

        // cliff = delai avant que argent commence a tomber
        // ex: cliff = 4 mois et duration = 10 mois => commence a recevoir argent apres 4 mois pendant 10 mois
        // si 10 jetons sur 10 mois <=> 1 jeton max par mois

        // Crée et stocke un nouveau calendrier de vesting
        vestingSchedules[beneficiary] = VestingSchedule({
            creationTime: block.timestamp,
            cliff: cliff,
            duration: duration,
            totalAmount: totalAmount,
            releasedAmount: 0 ether
        });

        // N'oubliez pas de vérifier que les fonds sont bien transférés au contrat !
        // enleve a beneficiary totalAmount et les donnes à _TOKEN
        _TOKEN.transferFrom(beneficiary, address(this), totalAmount); // Transfer à la map interne de IERC20
    }

    function claimVestedTokens(address beneficiary) public nonReentrant {
        logAccess();

        // Logique pour permettre à un bénéficiaire de réclamer les jetons déjà libérés.
        // Calculez le montant disponible et transférez-le
        VestingSchedule memory v = vestingSchedules[beneficiary];

        if (cliffTimeNotReached(v, block.timestamp)) {
            console.log("Cliff time not reached yet");
            return;
        }

        uint256 claimableAmount = getVestedAmount(beneficiary);

        // Check underflow
        if (v.totalAmount < claimableAmount) {
            console.log("The total amount is lower than the claimed amount, aborting");
            return;
        }
        v.totalAmount -= claimableAmount;

        // Check overflow
        if (v.releasedAmount >= type(uint256).max - claimableAmount) {
            console.log("Released amount would overflow if the claimableAmount was added to it.");
            return;
        }
        v.releasedAmount += claimableAmount;

        // Send tokens to the user
        _TOKEN.transfer(beneficiary, claimableAmount);
    }

    // Fonction pour calculer le montant total de jetons libérés à un instant T
    function getVestedAmount(address beneficiary) public returns (uint256) {
        logAccess();

        VestingSchedule memory v = vestingSchedules[beneficiary];

        uint256 current = block.timestamp;

        if (cliffTimeNotReached(v, current)) {
            console.log("Cliff time not reached yet");
            return 0;
        }

        // Attention : la libération est linéaire après le cliff.
        if (current < v.creationTime + v.cliff) {
            console.log("Cliff not reached yet, you cannnot claim anything");
            return 0;
        }

        uint256 perSecond = v.totalAmount / v.duration;
        uint256 remaining = v.totalAmount - v.releasedAmount;
        uint256 elapsedTimeSinceCreation = current - v.creationTime - v.cliff;
        uint256 claimable = elapsedTimeSinceCreation * perSecond;
        if (claimable > remaining) {
            console.log("Not enough tokens remaining, claiming the rest.");
            return remaining;
        }

        // console.log(string.concat("Per second = ", Strings.toString(perSecond)));
        // console.log(string.concat("Remaining = ", Strings.toString(remaining)));
        // console.log(string.concat("Elapsed since creation = ", Strings.toString(elapsedTimeSinceCreation)));
        // console.log(string.concat("Claimable = ", Strings.toString(claimable)));
        return claimable;
    }

    function cliffTimeNotReached(VestingSchedule memory v, uint256 current) private pure returns (bool) {
        return current < v.creationTime + v.cliff;
    }
}

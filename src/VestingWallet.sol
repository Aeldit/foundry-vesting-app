// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VestingWallet is Ownable, ReentrancyGuard {
    struct VestingSchedule {
        uint256 creationTime;
        uint256 cliff;
        uint256 duration;
        uint256 totalAmount;
        uint256 releasedAmount;
    }

    IERC20 public immutable _TOKEN;
    mapping(address => VestingSchedule) public vestingSchedules;

    constructor(address tokenAddress) Ownable(msg.sender) {
        _TOKEN = IERC20(tokenAddress);
    }

    function viewVestingSchedules(address beneficiary) public view returns (VestingSchedule memory) {
        return vestingSchedules[beneficiary];
    }

    function createVestingSchedule(address beneficiary, uint256 totalAmount, uint256 cliff, uint256 duration)
        public
        onlyOwner
    {
        // cliff = delai avant que argent commence a tomber
        // ex: cliff = 4 mois et duration = 10 mois => commence a recevoir argent apres 4 mois pendant 10 mois
        // si 10 jetons sur 10 mois <=> 1 jeton max par mois

        // Crée et stocke un nouveau calendrier de vesting
        vestingSchedules[beneficiary] = VestingSchedule({
            creationTime: block.timestamp, cliff: cliff, duration: duration, totalAmount: totalAmount, releasedAmount: 0
        });

        // N'oubliez pas de vérifier que les fonds sont bien transférés au contrat !
        // enleve a _TOKEN totalAmount
        _TOKEN.transferFrom(beneficiary, address(this), totalAmount); // Transfer à la map interne de IERC20
    }

    function claimVestedTokens(address beneficiary) public nonReentrant {
        // Logique pour permettre à un bénéficiaire de réclamer les jetons déjà libérés.
        // Calculez le montant disponible et transférez-le
        VestingSchedule memory v = vestingSchedules[beneficiary];

        if (cliffTimeNotReached(v, block.timestamp)) {
            console.log("Cliff time not reached yet");
            return;
        }

        uint256 claimableAmount = getVestedAmount(beneficiary);
        if (v.totalAmount < claimableAmount) {
            console.log("The total amount is lower than the claimed amount, aborting'");
            return;
        }
        v.totalAmount -= claimableAmount;
        v.releasedAmount += claimableAmount;

        (bool sent,) = msg.sender.call{value: claimableAmount}("");
        require(sent, "Failed to send Ether");
    }

    function getVestedAmount(address beneficiary) public view returns (uint256) {
        // Fonction pour calculer le montant total de jetons libérés à un instant T.

        VestingSchedule memory v = vestingSchedules[beneficiary];

        uint256 current = block.timestamp;

        // Attention : la libération est linéaire après le cliff.
        if (cliffTimeNotReached(v, current)) {
            console.log("Cliff time not reached yet");
            return 0;
        }

        // if ()

        // On peut claim le nombre de secondes depuis le debut du block
        return current - v.totalAmount;
    }

    function cliffTimeNotReached(VestingSchedule memory v, uint256 current) private pure returns (bool) {
        return current < v.creationTime + v.cliff;
    }
}

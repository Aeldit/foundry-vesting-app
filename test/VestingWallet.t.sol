// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {VestingWallet} from "../src/VestingWallet.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract VestingWalletTest is Test {
    VestingWallet public v;
    MockERC20 fakeToken;

    // Cette fonction s'exécute avant chaque test.
    function setUp() public {
        fakeToken = new MockERC20("fakeToken", "ft", 5);
        v = new VestingWallet(address(fakeToken));
    }

    // Test pour vérifier la fonction setNumber
    function test_CreateVestingSchedule() public {
        address beneficiary = address(0x180697f268232169e355ee184b795407aDCB329A);

        // 5 tokens per second for 10 second after 11 seconds have passed
        uint256 cliff = 11;
        uint256 duration = 10;
        uint256 totalAmount = 5;
        console.log(fakeToken.balanceOf(beneficiary));

        benefApprove(beneficiary, totalAmount);

        v.createVestingSchedule(beneficiary, totalAmount, cliff, duration);

        vm.warp(block.timestamp + 14);
        v.claimVestedTokens(beneficiary);

        // assertEq vérifie si les deux valeurs sont égales.
        assertEq(v.viewVestingSchedules(beneficiary).cliff, cliff, "The beneficiary should be %d");
    }

    function benefApprove(address beneficiary, uint256 amount) private {
        vm.prank(beneficiary);
        fakeToken.approve(address(v), amount);
    }
}

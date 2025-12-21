// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {VestingWallet} from "../src/VestingWallet.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract VestingWalletTest is Test {
    VestingWallet public v;
    MockERC20 fakeToken;

    // Cette fonction s'exécute avant chaque test.
    function setUp() public {
        fakeToken = new MockERC20("fakeToken", "ft", 50 ether);
        v = new VestingWallet(address(fakeToken));
    }

    function test_CreateVestingSchedule() public {
        address beneficiary = address(0x180697f268232169e355ee184b795407aDCB329A);

        uint256 cliff = 11;
        uint256 duration = 10;
        uint256 totalAmount = 20 ether;
        print("fakeToken balance : ", fakeToken.balanceOf(beneficiary));

        benefApprove(beneficiary, totalAmount);
        v.createVestingSchedule(beneficiary, totalAmount, cliff, duration);

        vm.warp(block.timestamp + 12);
        v.claimVestedTokens(beneficiary);

        v.checkAccessLog();

        assertEq(v.viewVestingSchedules(beneficiary).cliff, cliff, "The beneficiary should be %d");
    }

    function benefApprove(address beneficiary, uint256 amount) private {
        vm.prank(beneficiary);
        fakeToken.approve(address(v), amount);
    }

    // Helper to print a string and an integer value
    function print(string memory s, uint256 value) private pure {
        console.log(string.concat(s, Strings.toString(value)));
    }
}

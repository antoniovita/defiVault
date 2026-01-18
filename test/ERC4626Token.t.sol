// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC4626Token} from "../src/ERC4626Token.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ERC4626TokenTest is Test {
    MockERC20 public asset;
    ERC4626Token public vault;

    address public alice = address(0xA11CE);
    address public bob   = address(0xB0B);

    function setUp() public {
        asset = new MockERC20();
        vault = new ERC4626Token(IERC20(address(asset)), "Vault Share", "vSHARE", 18);
        asset.mint(alice, 1_000 ether);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
    }

    function test_Deposit_MintsShares_AndMovesAssets() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100 ether, alice);

        assertEq(shares, 100 ether, "initial deposit should be 1:1");
        assertEq(vault.balanceOf(alice), 100 ether, "shares minted");
        assertEq(vault.totalSupply(), 100 ether, "totalSupply updated");

        assertEq(asset.balanceOf(alice), 900 ether, "assets pulled from alice");
        assertEq(asset.balanceOf(address(vault)), 100 ether, "assets held by vault");
        assertEq(vault.totalAssets(), 100 ether, "totalAssets matches vault balance");
    }

    function test_Withdraw_BurnsShares_AndSendsAssets() public {
        vm.startPrank(alice);
        vault.deposit(100 ether, alice);
        uint256 sharesBurned = vault.withdraw(40 ether, alice, alice);
        vm.stopPrank();
        assertEq(sharesBurned, 40 ether, "shares burned should equal assets withdrawn at 1:1");
        assertEq(vault.balanceOf(alice), 60 ether, "shares reduced");
        assertEq(vault.totalSupply(), 60 ether, "totalSupply reduced");
        assertEq(asset.balanceOf(alice), 940 ether, "alice received assets back");
        assertEq(asset.balanceOf(address(vault)), 60 ether, "vault assets reduced");
    }

    function test_Redeem_BurnsExactShares_AndReturnsAssets() public {
        vm.prank(alice);
        vault.deposit(100 ether, alice);
        vm.prank(alice);
        uint256 assetsOut = vault.redeem(25 ether, alice, alice);
        assertEq(assetsOut, 25 ether, "assets out at 1:1");
        assertEq(vault.balanceOf(alice), 75 ether, "shares reduced");
        assertEq(asset.balanceOf(alice), 925 ether, "assets returned");
    }

    function test_Withdraw_BySpender_RequiresShareAllowance() public {
        vm.prank(alice);
        vault.deposit(100 ether, alice);

        vm.prank(bob);
        vm.expectRevert();
        vault.withdraw(10 ether, bob, alice);

        vm.prank(alice);
        vault.approve(bob, 50 ether);

        vm.prank(bob);
        uint256 sharesBurned = vault.withdraw(10 ether, bob, alice);

        assertEq(sharesBurned, 10 ether, "1:1 burn");
        assertEq(asset.balanceOf(bob), 10 ether, "bob received assets");
        assertEq(vault.balanceOf(alice), 90 ether, "alice shares reduced");
    }

    function test_PreviewWithdraw_RoundsUp() public {

        vm.prank(alice);
        vault.deposit(3 ether, alice);

        asset.mint(address(vault), 1 ether);

        uint256 sharesNeeded = vault.previewWithdraw(1 ether);
        assertEq(sharesNeeded, 1 ether, "should round up to 1 share");

        sharesNeeded = vault.previewWithdraw(2 ether);
        assertEq(sharesNeeded, 2 ether, "should round up to 2 shares");
    }
}

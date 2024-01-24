// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {WETH9} from "../src/WETH9.sol";
import {Handler} from "./handlers/Handler.sol";

contract WETH9Invariants is Test {
    WETH9 public weth;
    Handler public handler;

    function setUp() public {
        weth = new WETH9();
        handler = new Handler(weth);

        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.withdraw.selector;
        selectors[2] = Handler.sendFallback.selector;
        selectors[3] = Handler.approve.selector;
        selectors[4] = Handler.transfer.selector;
        selectors[5] = Handler.transferFrom.selector;
        selectors[6] = Handler.forcePush.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));

        targetContract(address(weth));
    }

    function invariant_conservationOfETH() public {
        assertEq(handler.ETH_SUPPLY(), address(handler).balance + weth.totalSupply());
    }

    // function invariant_solvencyBalances() public {
    //     uint256 sumOfBalances;
    //     address[] memory actors = handler.actors();
    //     for (uint256 i; i < actors.length; ++i) {
    //         sumOfBalances += weth.balanceOf(actors[i]);
    //     }
    //     assertEq(address(weth).balance, sumOfBalances);
    // }

    function invariant_depositorBalances() public {
        handler.forEachActor(this.assertAccountBalanceLteTotalSupply);
    }

 

    function assertAccountBalanceLteTotalSupply(address account) external {
        assertLe(weth.balanceOf(account), weth.totalSupply());
    }

    function accumulateBalance(uint256 balance, address caller) external view returns (uint256) {
        return balance + weth.balanceOf(caller);
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }

     function invariant_solvencyDeposits() public {
        assertEq(
            address(weth).balance,
            handler.ghost_depositSum() +
            handler.ghost_forcePushSum() -
            handler.ghost_withdrawSum()
        );
    }

    // The WETH contract's Ether balance should always be
    // equal to the sum of individual balances plus any
    // force-pushed Ether in the contract
    function invariant_solvencyBalances() public {
        uint256 sumOfBalances = handler.reduceActors(0, this.accumulateBalance);
        assertEq(
            address(weth).balance - handler.ghost_forcePushSum(),
            sumOfBalances
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Strings} from "../src/utils/Strings.sol";

contract StringsTest is Test {
    function test_Zero() public pure {
        assertEq(Strings.toString(0), "0");
    }

    function test_SingleAndMultiDigit() public pure {
        assertEq(Strings.toString(7), "7");
        assertEq(Strings.toString(10), "10");
        assertEq(Strings.toString(1234567890), "1234567890");
    }

    function test_TrailingZeros() public pure {
        assertEq(Strings.toString(1000), "1000");
    }

    function test_MaxUint256() public pure {
        assertEq(
            Strings.toString(type(uint256).max),
            "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        );
    }

    function testFuzz_LengthMatchesDigitCount(uint256 value) public pure {
        uint256 digits = 1;
        uint256 temp = value;
        while (temp >= 10) {
            digits++;
            temp /= 10;
        }
        assertEq(bytes(Strings.toString(value)).length, digits);
    }
}

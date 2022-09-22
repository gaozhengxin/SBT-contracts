// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDCard {
    function onReceiveMessage(bytes memory msg) external;
}

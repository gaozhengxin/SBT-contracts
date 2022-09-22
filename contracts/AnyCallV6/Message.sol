// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDCard {
    function outbound(uint256 tokenId, address receiver) external;
    function inbound(uint256 tokenId, address receiver) external;
}
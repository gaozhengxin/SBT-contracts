pragma solidity ^0.8.0;

import "../MessageChannelBase.sol";

contract PseudoMessageChannel is MessageChannelBase {
    function send(uint256 toChainID, bytes memory message) external override {
        // Do nothing
        return;
    }

    address public caller = address(0);

    function receiveMessage(address client, bytes memory message) external {
        onReceive(client, caller, message);
    }
}

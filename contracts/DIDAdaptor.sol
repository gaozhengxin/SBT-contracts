// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Interface for DID adaptor.
 * Allow DAO users to sign up with 3rd party DID protocols, eg Binance SBT, ENS, etc.
 */
interface IDIDAdaptor {
    function connect(uint256 tokenId, bytes32 accountType, bytes memory sign_info) external virtual returns (bool);
    function verifyAccount(uint256 tokenId, address owner) view external virtual returns (bool);
    function disconnect(uint256 tokenId) external virtual returns (bool);
}

contract BinanceSBT is IDIDAdaptor {
    bytes32 constant AccountType_Binance = keccak256("BinanceSBT");
    address idcard;

    mapping(uint256 => uint256) public binanceSBTOf; // idcard => binance sbt

    function connect(
        uint256 tokenId,
        bytes32 accountType,
        bytes memory sign_info
    ) public override returns (bool) {
        require(msg.sender == idcard);
        if (accountType == AccountType_Binance) {
            uint256 binanceSBT_id = abi.decode(sign_info, (uint256));
            // TODO
            // check if (IERC721(binanceSBT).ownerOf(binanceSBT_id) == _ownerOf(tokenId));
            binanceSBTOf[tokenId] = binanceSBT_id;
            // TODO log
            return true;
        }
        return false;
    }

    function disconnect(uint256 tokenId) external override returns (bool) {
        require(msg.sender == idcard);
        binanceSBTOf[tokenId] = 0;
        // TODO log
        return true;
    }

    function verifyAccount(uint256 tokenId, address owner) public view override returns (bool) {
        // return (IERC721(binanceSBT).ownerOf(binanceSBTOf[tokenId]) == _ownerOf(tokenId));
        return true;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

interface IMultiHonor {
    function POC(uint256 tokenId) view external returns(uint64);
    function VEPower(uint256 tokenId) view external returns(uint64);
    function EventPower(uint256 tokenId) view external returns(uint64);
    function Total(uint256 tokenId) view external returns(uint64); 
    function Level(uint256 tokenId) view external returns(uint8);
}

contract IDNFT_v1 is ERC721EnumerableUpgradeable,OwnableUpgradeable {
    function initialize()public initializer{
        __ERC721_init_unchained("IDNFT", "IDNFT");
        __Ownable_init_unchained();
    }

    uint256 public tokenId;
    address public honor;

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(balanceOf(msg.sender) == 0);
    }

    function claim() external {
        _mint(msg.sender, tokenId);
        tokenId++;
    }

    function burn(uint256 tokenId) external {
        require(msg.sender == ownerOf(tokenId));
        _burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return _tokenURI(tokenId);
    }

    function _tokenURI(uint _tokenId) internal pure returns (string memory output) {
        uint lvl = IMultiHonor(honor).Level(_tokenId);
        output = string(abi.encodePacked('https://gateway.pinata.cloud/ipfs/QmTYwELcSgghx32VMsSGgWFQvCAqZ5tg6kKaPh2MSJfwAj/', toString(lvl)));
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT license
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract IDNFT_v1 is ERC721EnumerableUpgradeable,OwnableUpgradeable {
    function initialize()public initializer{
        __ERC721_init_unchained("IDNFT", "IDNFT");
        __Ownable_init_unchained();
    }

    uint256 public tokenId;

    function claim() external {
        require(balanceOf(msg.sender) == 0);
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
        output = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><defs><pattern id="img1" x="0" y="0" width="100%" height="100%"><image xlink:href="https://raw.githubusercontent.com/gaozhengxin/assets/main/MarketingNFT.gif" width="45%" height="45%" /></pattern></defs><rect width="100%" height="100%" fill="url(#img1)" /><text x="5" y="150" class="base">';
        output = string(abi.encodePacked(output, toString(_tokenId)));
        output = string(abi.encodePacked(output, '</text></svg>'));

        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "lock #', toString(_tokenId), '", "description": "veMULTI NFT", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));
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
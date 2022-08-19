// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IMultiHonor {
    function POC(uint256 tokenId) view external returns(uint64);
    function VEPower(uint256 tokenId) view external returns(uint64);
    function VEPoint(uint256 tokenId) view external returns(uint64);
    function EventPoint(uint256 tokenId) view external returns(uint64);
    function TotalPoint(uint256 tokenId) view external returns(uint64); 
    function Level(uint256 tokenId) view external returns(uint8);
    function addPOC(uint256[] calldata ids, uint64[] calldata poc, uint64 time) external;
}

interface IERC721Enumerable {
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract POC_SemiToken is IERC20 {
    address public honor;
    address public idcard;
    uint256 _totalSupply;
    address public owner;
    address public pendingOwner;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwner(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
    }

    function acceptOwner() external {
        require(msg.sender == pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    event SetIssuer(address indexed issuer, uint256 cap);

    mapping(address => uint256) public cap;
    mapping(address => mapping(address => uint256)) public _allowance;

    function setIssuer(address issuer, uint256 cap_) external onlyOwner {
        cap[issuer] = cap_;
        emit SetIssuer(issuer, cap_);
    }

    function balanceOf(address account) external view returns (uint256) {
        uint256 tokenId = IERC721Enumerable(idcard).tokenOfOwnerByIndex(account, 0);
        return IMultiHonor(honor).POC(tokenId);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    // issue poc by issuer
    function transfer(address to, uint256 amount) external returns (bool) {
        require(cap[msg.sender] > amount, "transfer not allowed");
        cap[msg.sender] -= amount;
        uint256 tokenId = IERC721Enumerable(idcard).tokenOfOwnerByIndex(to, 0);
        uint256[] memory ids;
        uint64[] memory pocs;
        ids[0] = tokenId;
        pocs[0] = uint64(amount);
        IMultiHonor(honor).addPOC(ids, pocs, uint64(block.timestamp));
        _totalSupply += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // issue poc from issuer
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(cap[from] > amount, "transfer not allowed");
        _allowance[msg.sender][from] -= amount;
        cap[from] -= amount;
        uint256 tokenId = IERC721Enumerable(idcard).tokenOfOwnerByIndex(to, 0);
        uint256[] memory ids;
        uint64[] memory pocs;
        ids[0] = tokenId;
        pocs[0] = uint64(amount);
        IMultiHonor(honor).addPOC(ids, pocs, uint64(block.timestamp));
        _totalSupply += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // issuer's allowance to spender
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowance[owner][spender];
    }

    // issuer approve to spender
    function approve(address spender, uint256 amount) external returns (bool) {
        _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

interface IMultiHonor {
    function POC(uint256 tokenId) external view returns (uint64);

    function VEPower(uint256 tokenId) external view returns (uint64);

    function EventPower(uint256 tokenId) external view returns (uint64);

    function Total(uint256 tokenId) external view returns (uint64);

    function Level(uint256 tokenId) external view returns (uint8);
}

/** @dev Interface for DAO subsystems that depend on idcard, eg MultiHonor
 */
interface ILedger {
    /// @dev A hook function that executes when IDCards got merged.
    function merge(address fromToken, address toToken) external virtual;
    function lock(uint256 tokenId) external virtual returns (bytes memory info);
    function unlock(uint256 tokenId, bytes memory info) external virtual;
}

interface IMessage {
    function send(
        uint256 toChainID,
        bytes memory message
    ) external virtual;
}

/**
 * @dev Interface for DID adaptor.
 * Allow DAO users to sign up with 3rd party DID protocols, eg Binance SBT, ENS, etc.
 */
interface IDIDAdaptor {
    function connect(
        uint256 tokenId,
        bytes32 accountType,
        bytes memory sign_info
    ) external returns (bool);

    function verifyAccount(uint256 tokenId, address owner)
        external
        view
        returns (bool);

    function disconnect(uint256 tokenId) external virtual returns (bool);
}

/**
 * ID card NFT for MultiDAO
 */
contract IDCard_Doublechain is
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable
{
    function initialize() public initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __initRole();
        __ERC721_init_unchained("IDNFT", "IDNFT");
    }

    uint256 constant MaxSupply = 1000000000;

    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
    bytes32 public constant ROLE_MESSAGE = keccak256("ROLE_MESSAGE");
    bytes32 public constant ROLE_GATEWAY = keccak256("ROLE_GATEWAY");

    uint256 public nextTokenId;
    address public honor;
    mapping(uint256 => bool) public isAllowTransfer;

    /// @dev A list of MultiDAO subsystem contracts.
    address[] public ledgers;

    address public messageChannel;

    event SetHonor(address honor);
    event AllowTransfer(uint256 tokenId);
    event ForbidTransfer(uint256 tokenId);

    function __initRole() internal {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setHonor(address honor_) external {
        _checkRole(ROLE_ADMIN);
        honor = honor_;
        emit SetHonor(honor);
    }

    function allowTransfer(uint256 tokenId) external {
        _checkRole(ROLE_ADMIN);
        isAllowTransfer[tokenId] = true;
        emit AllowTransfer(tokenId);
    }

    function forbidTransfer(uint256 tokenId) external {
        _checkRole(ROLE_ADMIN);
        isAllowTransfer[tokenId] = false;
        emit ForbidTransfer(tokenId);
    }

    // Only tokenIds which are approved by contract owner can be transferred
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(!isLocked[tokenId], "token id is locked");
        require(isAllowTransfer[tokenId], "transfer is forbidden");
        isAllowTransfer[tokenId] = false;
        require(balanceOf(to) == 0, "receiver already has an ID card");
    }

    bytes32 constant AccountType_Default = bytes32("Default");

    mapping(uint256 => bytes32) public accountTypeOf;
    mapping(bytes32 => address) public dIDAdaptor;

    bool allowBlankSignup = false;

    function setDIDAdaptor(string calldata key, address adaptor) public {
        _checkRole(ROLE_ADMIN);
        dIDAdaptor[keccak256(key)] = adaptor;
        // TODO log
    }

    /**
     * @dev Connect a DID account.
     * @param accountType DID protocol type, eg whitelist, ENS holder checker, Binance SBT holder checker.
     * @param sign_info DID account verification info.
     */
    function _connect(
        uint256 tokenId,
        bytes32 accountType,
        bytes memory sign_info
    ) internal virtual returns (bool res) {
        require(accountTypeOf[tokenId] == bytes32(0));
        if (accountType == AccountType_Default) {
            require(allowBlankSignup);
            res = true;
        }
        res = IDIDAdaptor(dIDAdaptor[accountType]).connect(
            tokenId,
            accountType,
            sign_info
        );
        if (res) {
            accountTypeOf[tokenId] = accountType;
        }
        // TODO log
        return res;
    }

    function verifyAccount(uint256 tokenId) public view virtual returns (bool) {
        bytes32 accountType = accountTypeOf[tokenId];
        if (accountType == AccountType_Default) {
            return true;
        }
        return
            IDIDAdaptor(dIDAdaptor[accountType]).verifyAccount(
                tokenId,
                msg.sender
            );
    }

    function updateAccountInfo(
        uint256 tokenId,
        bytes32 newAccountType,
        bytes memory new_sign_info
    ) public {
        require(msg.sender == _ownerOf(fromToken), "check token owner fail");
        disconnect(tokenId);
        _connect(tokenId, newAccountType, new_sign_info);
    }

    function disconnect(uint256 tokenId) public returns (bool res) {
        require(
            msg.sender == _ownerOf(fromToken) || verifyAccount(tokenId),
            "neither token owner nor DID owner"
        );
        res = IDIDAdaptor(dIDAdaptor[accountTypeOf[tokenId]]).disconnect(
            tokenId
        );
        if (res) {
            accountTypeOf[tokenId] = bytes32(0);
        }
        // TODO log
    }

    /**
     * @dev Mints NFT to msg sender.
     * @param accountType DID protocol type, eg whitelist, ENS holder checker, Binance SBT holder checker.
     * @param sign_info DID account verification info.
     */
    function claim(bytes32 accountType, bytes memory sign_info)
        external
        returns (uint256 tokenId)
    {
        tokenId = nextTokenId;
        tokenId = tokenId + block.chainid * MaxSupply;
        require(_connect(tokenId, accountType, sign_info));
        isAllowTransfer[tokenId] = true;
        _mint(msg.sender, tokenId);
        isAllowTransfer[tokenId] = false;
        nextTokenId++;
        // TODO log
    }

    string _baseURI = "https://multichaindao.org/idcard/";

    function setBaseURI(string baseURI) public {
        _checkRole(ROLE_ADMIN);
        _baseURI = baseURI;
        // TODO log
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        _requireMinted(tokenId);
        return _tokenURI(tokenId);
    }

    function _tokenURI(uint256 _tokenId)
        internal
        view
        returns (string memory output)
    {
        uint256 lvl = IMultiHonor(honor).Level(_tokenId);
        output = string(abi.encodePacked(_baseURI, toString(lvl)));
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

    function getChainID(uint256 tokenId) pure returns (uint256 chainID) {
        chainID = tokenId / MaxSupply;
        if (chainID == 0) {
            chainID = 137;
        }
        return chainID;
    }

    /**
     * @dev Merges 2 idcards.
     * @param fromToken is burned.
     * @param toToken's owner remains unchanged.
     */
    function merge(uint256 fromToken, uint256 toToken) external {
        require(msg.sender == _ownerOf(fromToken), "check token owner fail"); // asserting fromToken exists on this chain
        require(!isLocked[fromToken]);
        require(verifyAccount(fromToken), "verify DID fail");
        bytes memory args = abi.encode(fromToken, toToken);
        bytes memory message = abi.encode(bytes4(keccak256("merge")), args);
        if (getChainID(toToken) == block.chainid) {
            _merge(fromToken, toToken);
        } else {
            IMessage(messageChannel).send(getChainID(toToken), message);
        }
        // TODO log
    }

    function onReceiveMessage(bytes memory message) external {
        _checkRole(ROLE_MESSAGE);
        (bytes4 func, bytes args) = abi.decode(message);
        if (func == bytes4(keccak256("merge"))) {
            (uint256 fromToken, uint256 toToken) = abi.decode(args);
            if (getChainID(toToken) == block.chainid) {
                _merge(fromToken, toToken);
            }
        }
    }

    function _merge(uint256 fromToken, uint256 toToken) internal {
        mergeLedgers(fromToken, toToken);
        _burn(fromToken);
    }

    /**
     * @dev merge one token to another
     */
    function mergeLedgers(uint256 fromToken, uint256 toToken) internal {
        require(fromToken != toToken);
        require(_exists(toToken) && !isLocked(toToken));
        for (uint256 i = 0; i < ledgers.length; i++) {
            ILedger(ledgers[i]).merge(fromToken, toToken);
        }
    }

    function lockLedgers(uint256 tokenId) internal returns (bytes[] memory) {
        // TODO
    }

    /**
     * Token Gateway functions.
     */
    mapping(uint256 => bool) public isLocked;

    function lock(uint256 tokenId) internal returns (bytes[] memory info) {
        // TODO
        isLocked[tokenId] = true;
    }

    function unlock(uint256 tokenId, bytes[] memory info) internal {
        // TODO
        isLocked[tokenId] = false;
    }

    /**
     * @dev Runs when bridging out.
     * Locks token id, so that it is not transferable,
     * but does not change the ownership or burn the token id.
     */
    function outbound(uint256 tokenId, address receiver) external returns (bytes memory info) {
        _checkRole(ROLE_GATEWAY);
        isLocked[tokenId] = true;
        // TODO log
    }

    /**
     * @dev Runs when bridging in.
     * Unlock token id if it exists. Mint token id if not exists.
     */
    function inbound(uint256 tokenId, address receiver, bytes memory info) external {
        _checkRole(ROLE_GATEWAY);
        if (!_exists(tokenId)) {
            isAllowTransfer[tokenId] = true;
            _mint(owner, tokenId);
            isAllowTransfer[tokenId] = false;
        }
        require(_ownerOf(tokenId) == receiver);
        isLocked[tokenId] = false;
        // TODO log
    }
}

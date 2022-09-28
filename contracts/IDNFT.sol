// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

interface IMultiHonor {
    function Level(uint256 tokenId) external view returns (uint8);
}

/**
 * @dev Interface for DAO subsystems that depend on idcard, eg MultiHonor
 */
interface ILedger {
    /// @dev A hook function that executes when IDCards got merged.
    function merge(uint256 fromToken, uint256 toToken) external virtual;
}

/**
 * @dev Interface of crosschain message channel.
 */
interface IMessageChannel {
    function send(uint256 toChainID, bytes memory message) external virtual;
}

/**
 * @dev Interface for DID adaptor.
 * Allow DAO users to sign up with 3rd party DID protocols, eg Binance SBT, ENS, etc.
 */
interface IDIDAdaptor {
    function connect(
        uint256 tokenId,
        address claimer,
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
 * ID card NFT is a collection of crosschain composable DID NFT.
 * ID card is connecting to different underlying DID systems on different chains with adaptors.
 */
contract IDCard_V2 is ERC721EnumerableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
    bytes32 public constant ROLE_MESSAGE = keccak256("ROLE_MESSAGE");

    bool v2Initialized;

    uint256 maxTokenIdId;
    uint256 public nextTokenId;

    string _baseURI_;
    address public honor;

    bool public transferable;
    mapping(uint256 => bool) public isAllowTransfer;

    /// @dev Message channel adaptor address.
    address public messageChannel;
    /// @dev Peer chains.
    uint256[] public chains;
    mapping(address => mapping(bytes4 => bool)) public callerPermission; // caller -> function -> allowed
    bytes4 FuncMerge = bytes4(keccak256("merge"));
    bytes4 FuncSignin = bytes4(keccak256("signin"));

    /// @dev Type of DID that IDCard is connected to.
    mapping(uint256 => bytes32) public accountTypeOf;
    /// @dev Default account type.
    bytes32 constant AccountType_Default = bytes32("Default");
    /// @dev DID adaptor contracts for different DID types.
    mapping(bytes32 => address) public dIDAdaptor;

    /// @dev A list of MultiDAO subsystem contracts.
    address[] public ledgers;

    /// @dev Allow claim IDCard without connecting to any DID.
    bool allowBlankSignup = false;

    event InitV2();

    event SetBaseURI(string baseURI);

    event SetHonor(address honor);

    event SetTransferable(bool transferable);
    event AllowTransfer(uint256 tokenId);
    event ForbidTransfer(uint256 tokenId);

    event SetMessageChannel(address messageChannel);
    event SetChains(uint256[] chains);
    event SetCallerPermission(address caller, bytes4 func, bool allow);

    event SetDIDAdaptor(string key, bytes32 hashkey, address adaptor);

    event RegisterLedger(address ledger);
    event RemoveLedger(address ledger);

    event Claim(uint256 tokenId, address owner);
    event Connect(uint256 tokenId, bytes32 accountType, bytes signinfo);
    event Disconnect(uint256 tokenId, bytes32 accountType);

    event Signin(uint256 tokenId, uint256[] toChainIDs, address receiverWallet);
    event Signin(uint256 tokenId, address receiverWallet);

    event MergeLocal(uint256 fromToken, uint256 toToken);
    event Merge(uint256 fromToken, uint256 toToken);
    event MergeError(address ledger, uint256 fromToken, uint256 toToken);

    modifier mustInitialized() {
        require(v2Initialized);
        _;
    }

    function initialize() public initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __initRole();
        __ERC721_init_unchained("IDNFT", "IDNFT");
    }

    function __initRole() internal {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @dev Initializes V2 settings.
    function initV2(address messageChannel_, bool transferable_) public {
        _checkRole(ROLE_ADMIN);
        require(!v2Initialized);
        maxTokenIdId = 1000000000;
        _setBaseURI("ipfs://QmTYwELcSgghx32VMsSGgWFQvCAqZ5tg6kKaPh2MSJfwAj/");
        _setMessageChannel(messageChannel_);
        _setTransferable(transferable_);
        v2Initialized = true;
        emit InitV2();
    }

    /// @dev Sets base URI.
    function setBaseURI(string memory baseURI) public {
        _checkRole(ROLE_ADMIN);
        _setBaseURI(baseURI);
    }

    function _setBaseURI(string memory baseURI) internal {
        _baseURI_ = baseURI;
        emit SetBaseURI(_baseURI_);
    }

    /// @dev Sets MultiHonor address.
    function setHonor(address honor_) external {
        _checkRole(ROLE_ADMIN);
        honor = honor_;
        emit SetHonor(honor);
    }

    /// @dev Sets IDCard NFT as transferable or non-transferable.
    function setTransferable(bool transferable_) external {
        _checkRole(ROLE_ADMIN);
        _setTransferable(transferable_);
    }

    function _setTransferable(bool transferable_) internal {
        transferable = transferable_;
        emit SetTransferable(transferable);
    }

    /// @dev Sets tokenId as transferable.
    function allowTransfer(uint256 tokenId) external {
        _checkRole(ROLE_ADMIN);
        isAllowTransfer[tokenId] = true;
        emit AllowTransfer(tokenId);
    }

    /// @dev Sets tokenId as non-transferable.
    function forbidTransfer(uint256 tokenId) external {
        _checkRole(ROLE_ADMIN);
        isAllowTransfer[tokenId] = false;
        emit ForbidTransfer(tokenId);
    }

    /// @dev Sets message channel (adaptor) address.
    function setMessageChannel(address messageChannel_) external {
        _checkRole(ROLE_ADMIN);
        _setMessageChannel(messageChannel_);
    }

    function _setMessageChannel(address messageChannel_) internal {
        messageChannel = messageChannel_;
        emit SetMessageChannel(messageChannel);
    }

    /// @dev Sets peer chains.
    function setChains(uint256[] memory chains_) external {
        _checkRole(ROLE_ADMIN);
        chains = chains_;
        emit SetChains(chains);
    }

    /// @dev Sets remote caller's permission.
    function setCallerPermission(
        address caller,
        bytes4 func,
        bool allow
    ) external {
        _checkRole(ROLE_ADMIN);
        callerPermission[caller][func] = allow;
        emit SetCallerPermission(caller, func, allow);
    }

    /// @dev Sets DID adaptor address.
    function setDIDAdaptor(string memory key, address adaptor) public {
        _checkRole(ROLE_ADMIN);
        dIDAdaptor[keccak256(bytes(key))] = adaptor;
        emit SetDIDAdaptor(key, keccak256(bytes(key)), adaptor);
    }

    /// @dev Register ledger.
    function registerLedgers(address ledger) external {
        _checkRole(ROLE_ADMIN);
        for (uint256 i = 0; i < ledgers.length; i++) {
            if (ledgers[i] == ledger) {
                revert("already exists");
            }
        }
        ledgers.push(ledger);
        emit RegisterLedger(ledger);
    }

    /// @dev Remove ledger.
    function removeLedger(address ledger) external {
        _checkRole(ROLE_ADMIN);
        uint256 index = 0;
        for (uint256 i = 0; i < ledgers.length; i++) {
            if (ledgers[i] == ledger) {
                index = i + 1;
                break;
            }
        }
        index--;
        for (uint256 i = index; i < ledgers.length - 1; i++) {
            ledgers[i] = ledgers[i + i];
        }
        ledgers.pop();
        emit RemoveLedger(ledger);
    }

    /// @dev Check if token is transferable before transfer.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(
            transferable || isAllowTransfer[tokenId],
            "transfer is forbidden"
        );
        isAllowTransfer[tokenId] = false;
        require(balanceOf(to) == 0, "receiver already has an ID card");
    }

    /// @dev Dispatches message to different functions.
    function onReceiveMessage(address caller, bytes memory message)
        external
        mustInitialized
    {
        _checkRole(ROLE_MESSAGE);
        (bytes4 func, bytes memory args) = abi.decode(message, (bytes4, bytes));
        if (func == FuncMerge) {
            require(callerPermission[caller][FuncMerge]);
            onMergeMessage(args);
            return;
        }
        if (func == FuncSignin) {
            require(callerPermission[caller][FuncSignin]);
            onSigninMessage(args);
            return;
        }
    }

    /// @dev Returns birth chain of the IDCard.
    function getChainID(uint256 tokenId)
        public
        view
        mustInitialized
        returns (uint256 chainID)
    {
        chainID = tokenId / maxTokenIdId;
        if (chainID == 0) {
            chainID = 137;
        }
        return chainID;
    }

    /**
     * @dev Mints NFT to msg sender.
     * @param accountType DID protocol type, eg whitelist, ENS holder checker, Binance SBT holder checker.
     * @param sign_info DID account verification info.
     */
    function claim(bytes32 accountType, bytes memory sign_info)
        external
        mustInitialized
        returns (uint256 tokenId)
    {
        tokenId = nextTokenId;
        tokenId = tokenId + block.chainid * maxTokenIdId;
        require(_connect(tokenId, accountType, sign_info));
        isAllowTransfer[tokenId] = true;
        _mint(msg.sender, tokenId);
        isAllowTransfer[tokenId] = false;
        nextTokenId++;
        emit Claim(tokenId, msg.sender);
    }

    /**
     * @dev Connect a DID account.
     * @param accountType DID protocol type, eg MultiDAO whitelisted address, ENS holder, Binance BABT holder.
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
            msg.sender,
            accountType,
            sign_info
        );
        if (res) {
            accountTypeOf[tokenId] = accountType;
        }
        emit Connect(tokenId, accountType, sign_info);
        return res;
    }

    /// @dev Verifies if the IDCard holder is the owner of DID that is currently connecting to the IDCard.
    function verifyAccount(uint256 tokenId) public view virtual returns (bool) {
        require(getChainID(tokenId) == block.chainid);
        bytes32 accountType = accountTypeOf[tokenId];
        if (accountType == AccountType_Default) {
            return allowBlankSignup;
        }
        return
            IDIDAdaptor(dIDAdaptor[accountType]).verifyAccount(
                tokenId,
                msg.sender
            );
    }

    /// @dev Update idcard's DID.
    function updateAccountInfo(
        uint256 tokenId,
        bytes32 newAccountType,
        bytes memory new_sign_info
    ) public {
        require(msg.sender == _ownerOf(tokenId), "check token owner fail");
        disconnect(tokenId);
        _connect(tokenId, newAccountType, new_sign_info);
    }

    /// @dev Disconnect idcard with DID.
    function disconnect(uint256 tokenId) public returns (bool res) {
        require(
            msg.sender == _ownerOf(tokenId) || verifyAccount(tokenId),
            "neither token owner nor DID owner"
        );
        res = IDIDAdaptor(dIDAdaptor[accountTypeOf[tokenId]]).disconnect(
            tokenId
        );
        if (res) {
            accountTypeOf[tokenId] = bytes32(0);
        }
        emit Disconnect(tokenId, accountTypeOf[tokenId]);
    }

    /**
     * @dev Merges 2 idcards on all chains.
     * Merges tokens locally and send merge message to remote chains.
     */
    function merge(uint256 fromToken, uint256 toToken)
        external
        mustInitialized
    {
        require(msg.sender == _ownerOf(fromToken), "check token owner fail");
        require(_exists(toToken));
        _merge(fromToken, toToken);
        bytes memory args = abi.encode(fromToken, toToken);
        bytes memory message = abi.encode(FuncMerge, args);
        for (uint256 i = 0; i < chains.length; i++) {
            IMessageChannel(messageChannel).send(chains[i], message);
        }
        emit MergeLocal(fromToken, toToken);
    }

    function onMergeMessage(bytes memory message) internal {
        (uint256 fromToken, uint256 toToken) = abi.decode(
            message,
            (uint256, uint256)
        );
        _merge(fromToken, toToken);
    }

    /**
     * @dev Merges 2 idcards locally.
     */
    function _merge(uint256 fromToken, uint256 toToken) internal {
        if (!_exists(fromToken) || !_exists(toToken)) {
            return;
        }
        _burn(fromToken);
        emit Merge(fromToken, toToken);
    }

    /// @dev Calls registered ledgers to merge tokens.
    function mergeLedgers(uint256 fromToken, uint256 toToken) internal {
        require(fromToken != toToken);
        require(_exists(toToken));
        for (uint256 i = 0; i < ledgers.length; i++) {
            try ILedger(ledgers[i]).merge(fromToken, toToken) {} catch {
                emit MergeError(ledgers[i], fromToken, toToken);
            }
        }
    }

    /// @dev Sign IDCard to remote chains.
    function signin(
        uint256 tokenId,
        uint256[] calldata toChainIDs,
        address receiverWallet
    ) external mustInitialized {
        bytes memory args = abi.encode(tokenId, receiverWallet);
        bytes memory message = abi.encode(FuncSignin, args);
        for (uint256 i = 0; i < toChainIDs.length; i++) {
            IMessageChannel(messageChannel).send(chains[i], message);
        }
        emit Signin(tokenId, toChainIDs, receiverWallet);
    }

    function onSigninMessage(bytes memory message) internal {
        (uint256 tokenId, address receiverWallet) = abi.decode(
            message,
            (uint256, address)
        );
        _mint(receiverWallet, tokenId);
        emit Signin(tokenId, receiverWallet);
    }

    /// @dev Returns token URI.
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
        output = string(abi.encodePacked(_baseURI_, toString(lvl)));
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

    function supportsInterface(bytes4 interfaceID)
        public
        view
        override(AccessControlUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return false;
    }
}

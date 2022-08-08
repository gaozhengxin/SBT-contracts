// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

interface IMultiHonor {
    function POC(uint256 tokenId) view external returns(uint64);
    function VEPower(uint256 tokenId) view external returns(uint64);
    function EventPower(uint256 tokenId) view external returns(uint64);
    function Total(uint256 tokenId) view external returns(uint64); 
    function Level(uint256 tokenId) view external returns(uint8);
}

contract MultiHonor_V1 is IMultiHonor, AccessControlUpgradeable {
    function initialize() public initializer {
        __AccessControl_init_unchained();
        __initRole();
	}

    address public IDCard;
    bytes32 public constant ROLE_ROOT = keccak256("ROLE_ROOT");
    bytes32 public constant ROLE_ADD_POC = keccak256("ROLE_ADD_POC");
    bytes32 public constant ROLE_SET_POC = keccak256("ROLE_SET_POC");
    bytes32 public constant ROLE_SET_VEPOWER = keccak256("ROLE_SET_VEPOWER");
    bytes32 public constant ROLE_ADD_EVENT = keccak256("ROLE_ADD_EVENT");
    bytes32 public constant ROLE_SET_EVENT = keccak256("ROLE_SET_EVENT");

    function __initRole() internal {
        _setupRole(ROLE_ROOT, msg.sender);
        _setupRole(ROLE_ADD_POC, msg.sender);
        _setupRole(ROLE_SET_POC, msg.sender);
        _setupRole(ROLE_SET_VEPOWER, msg.sender);
        _setupRole(ROLE_ADD_EVENT, msg.sender);
        _setupRole(ROLE_SET_EVENT, msg.sender);
    }

    function setRoleRoot(address to) external {
        _checkRole(ROLE_ROOT);
        _setupRole(ROLE_ROOT, to);
    }

    function setRoleAddPOC(address to) external {
        _checkRole(ROLE_ROOT);
        _setupRole(ROLE_ADD_POC, to);

    }

    function setRoleSetPOC(address to) external {
        _checkRole(ROLE_ROOT);
        _setupRole(ROLE_SET_POC, to);

    }

    function setRoleSetVEPower(address to) external {
        _checkRole(ROLE_ROOT);
        _setupRole(ROLE_SET_VEPOWER, to);
    }

    function setRoleSetEvent(address to) external {
        _checkRole(ROLE_ROOT);
        _setupRole(ROLE_SET_EVENT, to);
    }

    struct Info {
        uint64 POC;
        uint64 Timestamp;
        uint64 VEPower;
        uint64 EventPower;
    }

    mapping(uint256 => Info) private info;

    uint256 public k;
    uint256 constant k_denominator = 1000000;
    // uint256 constant p = 1000000000;

    // returns user's POC at a specific time after checkpoint
    function POC(uint256 tokenId, uint256 time) view external returns(uint64) {
        return uint64(uint256(info[tokenId].POC) - uint256(time - info[tokenId].Timestamp) * k / k_denominator);
        // Non linear attenuation
        // return p / (time - (info[tokenId].Timestamp - p / info[tokenId].POC));
    }

    // returns user's current POC
    function POC(uint256 tokenId) override view external returns(uint64) {
        return this.POC(tokenId, block.timestamp);
    }

    // returns user's current VEPower
    function VEPower(uint256 tokenId) override view external returns(uint64) {
        return info[tokenId].VEPower;
    }
    // returns user's current EventPower
    function EventPower(uint256 tokenId) override view external returns(uint64) {
        return info[tokenId].EventPower;
    }

    uint64 public level_5 = 200000;
    uint64 public level_4 = 100000;
    uint64 public level_3 = 30000;
    uint64 public level_2 = 5000;
    uint64 public level_1 = 1000;

    // returns user's level
    function Level(uint256 tokenId) override view external returns(uint8) {
        if (this.Total(tokenId) > level_5) {
            return 5;
        }
        if (this.Total(tokenId) > level_4) {
            return 4;
        }
        if (this.Total(tokenId) > level_3) {
            return 3;
        }
        if (this.Total(tokenId) > level_2) {
            return 2;
        }
        if (this.Total(tokenId) > level_1) {
            return 1;
        }
    }

    uint256 public weight_poc = 300;
    uint256 public weight_vepower = 600;
    uint256 public weight_event = 100;

    // returns user's total honor
    function Total(uint256 tokenId) override view external returns(uint64) {
        return uint64((this.POC(tokenId) * weight_poc + this.VEPower(tokenId) * weight_vepower + this.EventPower(tokenId) * tokenId) / (weight_poc + weight_vepower + weight_event));
    }

    function setK(uint256 k_) external {
        _checkRole(ROLE_SET_POC);
        k = k_;
    }

    // @dev cover Poc point
    function setPOC(uint256[] calldata ids, uint64[] calldata poc, uint64 time) external {
        _checkRole(ROLE_SET_POC);
        require(uint256(time) <= block.timestamp);
        for (uint i = 0; i < ids.length; i++) {
            info[ids[i]].POC = poc[i];
            info[ids[i]].Timestamp = time;
        }
    }

    // @dev increase Poc value and update Poc check time
    function addPOC(uint256[] calldata ids, uint64[] calldata poc, uint64 time) external {
        _checkRole(ROLE_ADD_POC);
        require(uint256(time) <= block.timestamp);
        for (uint i = 0; i < ids.length; i++) {
            require(time >= info[ids[i]].Timestamp);
            uint64 poc_ = this.POC(ids[i], uint256(time)) + poc[i];
            info[ids[i]].POC = poc_;
            info[ids[i]].Timestamp = time;
        }
    }

    // @dev increase VE power
    function setVEPower(uint256[] calldata ids, uint64[] calldata vePower) external {
        _checkRole(ROLE_SET_VEPOWER);
        for (uint i = 0; i < ids.length; i++) {
            info[ids[i]].VEPower = vePower[i];
        }
    }

    function setEventPower(uint256[] calldata ids, uint64[] calldata eventPower) external {
        _checkRole(ROLE_SET_EVENT);
        for (uint i = 0; i < ids.length; i++) {
            info[ids[i]].EventPower = eventPower[i];
        }
    }

    // @dev increase event power
    function addEventPower(uint256[] calldata ids, uint64[] calldata eventPower) external {
        _checkRole(ROLE_ADD_EVENT);
        for (uint i = 0; i < ids.length; i++) {
            uint64 eventPower_ = this.EventPower(ids[i]) + eventPower[i];
            info[ids[i]].EventPower = eventPower_;
        }
    }

    function updateAll(uint256[] calldata ids, uint64[] calldata poc, uint64 time, uint64[] calldata vePower, uint64[] calldata eventPower) external {
        _checkRole(ROLE_ADD_POC);
        _checkRole(ROLE_SET_VEPOWER);
        _checkRole(ROLE_ADD_EVENT);
        for (uint i = 0; i < ids.length; i++) {
            require(time >= info[ids[i]].Timestamp);
            uint64 poc_ = this.POC(ids[i], uint256(time)) + poc[i];
            uint64 eventPower_ = this.EventPower(ids[i]) + eventPower[i];
            info[ids[i]] = Info(poc_, time, vePower[i], eventPower_);
        }
    }
}
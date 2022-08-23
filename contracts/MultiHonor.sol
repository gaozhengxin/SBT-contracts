// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IMultiHonor {
    function POC(uint256 tokenId) view external returns(uint64);
    function VEPower(uint256 tokenId) view external returns(uint64);
    function VEPoint(uint256 tokenId) view external returns(uint64);
    function EventPoint(uint256 tokenId) view external returns(uint64);
    function TotalPoint(uint256 tokenId) view external returns(uint64); 
    function Level(uint256 tokenId) view external returns(uint8);
}

contract MultiHonor_V1 is Initializable, IMultiHonor, AccessControlUpgradeable {
    function initialize() public initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __initRole();
        __initSBT();
	}

    address public IDCard;
    bytes32 public constant ROLE_ADD_POC = keccak256("ROLE_ADD_POC");
    bytes32 public constant ROLE_SET_POC = keccak256("ROLE_SET_POC");
    bytes32 public constant ROLE_SET_VEPOWER = keccak256("ROLE_SET_VEPOWER");
    bytes32 public constant ROLE_ADD_EVENT = keccak256("ROLE_ADD_EVENT");
    bytes32 public constant ROLE_SET_EVENT = keccak256("ROLE_SET_EVENT");

    function __initRole() internal {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    uint256 public weight_poc;
    uint256 public weight_vepoint;
    uint256 public weight_event;

    uint256 public k;
    uint256 constant k_denominator = 1000000;
    // uint256 constant p = 1000000000;

    function __initSBT() internal {
        weight_poc = 600;
        weight_vepoint = 300;
        weight_event = 100;
        k = 0;
    }

    function setIDCard(address IDCard_) external {
        _checkRole(DEFAULT_ADMIN_ROLE);
        IDCard = IDCard_;
    }

    struct Info {
        uint64 POC;
        uint64 Timestamp;
        uint64 VEPower;
        uint64 EventPoint;
    }

    mapping(uint256 => Info) private info;

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

    // returns user's current VEPoint
    function VEPoint(uint256 tokenId) override view external returns(uint64) {
        return uint64(vePower2vePoint(this.VEPower(tokenId)));
    }

    // returns user's current EventPoint
    function EventPoint(uint256 tokenId) override view external returns(uint64) {
        return info[tokenId].EventPoint;
    }

    function levelRequire(uint level) pure public returns(uint64) {
        if (level == 5) {
            return 200000;
        }
        if (level == 4) {
            return 100000;
        }
        if (level == 3) {
            return 30000;
        }
        if (level == 2) {
            return 5000;
        }
        if (level == 1) {
            return 1000;
        }
    }

    // returns user's level
    function Level(uint256 tokenId) override view external returns(uint8) {
        if (this.TotalPoint(tokenId) > levelRequire(5)) {
            return 5;
        }
        if (this.TotalPoint(tokenId) > levelRequire(4)) {
            return 4;
        }
        if (this.TotalPoint(tokenId) > levelRequire(3)) {
            return 3;
        }
        if (this.TotalPoint(tokenId) > levelRequire(2)) {
            return 2;
        }
        if (this.TotalPoint(tokenId) > levelRequire(1)) {
            return 1;
        }
        return 0;
    }

    // returns user's total honor
    function TotalPoint(uint256 tokenId) override view external returns(uint64) {
        return uint64((this.POC(tokenId) * weight_poc + this.VEPoint(tokenId) * weight_vepoint + this.EventPoint(tokenId) * tokenId) / (weight_poc + weight_vepoint + weight_event));
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

    function setEventPoint(uint256[] calldata ids, uint64[] calldata eventPower) external {
        _checkRole(ROLE_SET_EVENT);
        for (uint i = 0; i < ids.length; i++) {
            info[ids[i]].EventPoint = eventPower[i];
        }
    }

    // @dev increase event power
    function addEventPoint(uint256[] calldata ids, uint64[] calldata eventPower) external {
        _checkRole(ROLE_ADD_EVENT);
        for (uint i = 0; i < ids.length; i++) {
            uint64 eventPoint_ = this.EventPoint(ids[i]) + eventPower[i];
            info[ids[i]].EventPoint = eventPoint_;
        }
    }

    struct updateInfo {
        uint64 POC_Increase;
        uint64 VEPower;
        uint64 EventPoint_Increase;
    }

    function updateAll(uint256[] calldata ids, updateInfo[] calldata infos, uint256 time) external {
        _checkRole(ROLE_ADD_POC);
        _checkRole(ROLE_SET_VEPOWER);
        _checkRole(ROLE_ADD_EVENT);
        for (uint i = 0; i < ids.length; i++) {
            require(time >= info[ids[i]].Timestamp);
            uint64 poc_ = this.POC(ids[i], uint256(time)) + infos[i].POC_Increase;
            uint64 eventPower_ = this.EventPoint(ids[i]) + infos[i].EventPoint_Increase;
            info[ids[i]] = Info(poc_, uint64(time), infos[i].VEPower, eventPower_);
        }
    }

    function vePower2vePoint(uint256 v) public pure returns (uint256) {
        return 824 * lg(v / 1 ether +1) ** 2 + 500 * v / 1 ether / 1000;
    }

    function lg(uint256 x) public pure returns (uint256 y) {
        y = 0;
        for (uint i = 0; i < 255; i++) {
            x = x / 10;
            if (x == 0) {
                return y;
            }
            y++;
        }
        revert("exp max loops exceeded");
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DateTime.sol";

interface IBonusDistributor {
    event ClaimBonus(uint256 idcard, address toAccount, uint256 amount);

    function claimable(uint256 idcard) external view returns (uint256 amount);

    function claim(uint256 idcard, address toAccount)
        external
        returns (uint256 amount);
}

interface IERC20 {
    function decimals() external view returns (uint8);

    function transfer(address to, uint256 amount) external returns (bool);
}

interface IIDNFT {
    function ownerOf(uint256 _tokenId) external view returns (address);
}

interface IMultiHonor {
    function POC(uint256 tokenId) external view returns (uint64);
}

contract BonusDistributor is IBonusDistributor, DateTime {
    address public bonusToken;
    address public idnft;
    address public multiHonor;
    uint256 immutable bonusDay;

    mapping(uint256 => uint256) public historicPoints;

    constructor(address bonusToken_, address idnft_, address multiHonor_) {
        bonusDay = 15;
    }

    function currentMonthStart() public view returns (uint256 time) {
        uint16 y = getYear(block.timestamp);
        uint8 m = getMonth(block.timestamp);
        return toTimestamp(y, m, 1);
    }

    function claimable(uint256 idcard)
        public
        view
        override
        returns (uint256 amount)
    {
        if (block.timestamp < currentMonthStart() + bonusDay * DAY_IN_SECONDS) {
            return 0;
        }
        uint256 dpoc = getDpoc(idcard);
        uint8 decimal; // TODO
        amount = dpoc * 10**decimal;
        return amount;
    }

    function getDpoc(uint256 idcard) public view returns (uint256 dpoc) {
        uint256 poc = uint256(IMultiHonor(multiHonor).POC(idcard));
        dpoc = poc > historicPoints[idcard] ? poc - historicPoints[idcard] : 0;
        return dpoc;
    }

    function claim(uint256 idcard, address toAccount)
        external
        override
        returns (uint256 amount)
    {
        require(IIDNFT(idnft).ownerOf(idcard) == msg.sender, "bonus distributor: not idcard owner");
        if (block.timestamp < currentMonthStart() + bonusDay * DAY_IN_SECONDS) {
            return 0;
        }
        uint256 dpoc = getDpoc(idcard);
        uint8 decimal;
        amount = dpoc * 10**decimal;
        bool success = IERC20(bonusToken).transfer(toAccount, amount);
        require(success, "bonus distributor: send bonus token failed");
        historicPoints[idcard] += dpoc;
        emit ClaimBonus(idcard, toAccount, amount);
        return amount;
    }
}

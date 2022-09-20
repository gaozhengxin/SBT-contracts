// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Test {
    struct Point {
        uint256 v;
        uint256 p;
				uint256 t;
    }

    function testV2P() external pure returns(Point[] memory) {
        uint256[9] memory v = [uint256(0 ether), uint256(10 ether), uint256(100 ether), uint256(1000 ether), uint256(10000 ether), uint256(100000 ether), uint256(640000 ether), uint256(1000000 ether), uint256(10000000 ether)];
        Point[] memory point = new Point[](9);
        for (uint i = 0; i < 9; i++) {
			uint p = vePower2vePoint(v[i]);
			uint t = 3 * p / 10;
            point[i] = Point(v[i], p, t);
        }
        return point;
    }

    function vePower2vePoint(uint256 v) public pure returns (uint256) {
        return 250 * log_2(v / 1 ether +1) + 514 * v / 1 ether / 1000;
    }

    function log_2(uint256 x) public pure returns (uint256 y) {
        y = 0;
        for (uint i = 0; i < 255; i++) {
            x = x >> 1;
			if (x == 0) {
				return y;
			}
            y++;
        }
        revert("log_2 max loops exceeded");
    }
}
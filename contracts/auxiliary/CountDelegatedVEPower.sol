struct DelegateInfo {
    bool delegated;
    uint256 delegateTo;
    uint256 power;
}

interface IReceiver {
    function delegatedPower(uint256)
        external
        view
        returns (DelegateInfo memory);
}

contract DelegatedVEPowerCounter {
    address receiver;

    constructor(address _receiver) {
        receiver = _receiver;
    }

    function veKey(
        uint256 fromChainID,
        uint256 ve_id,
        uint256 epoch
    ) public pure returns (uint256) {
        // fromChainID 1, ve_id 2, epoch 3 => veKey 0x100000000000000020000000000000003
        return (fromChainID << 128) + (ve_id << 64) + epoch;
    }

    function count(
        uint256 fromChainID,
        uint256 start,
        uint256 end,
        uint256 epoch
    ) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = start; i <= end; i++) {
            uint256 key = veKey(fromChainID, i, epoch);
            DelegateInfo memory delegateInfo = IReceiver(receiver)
                .delegatedPower(key);
            if (delegateInfo.delegated == true) {
                total += delegateInfo.power;
            }
        }
        return total;
    }
}
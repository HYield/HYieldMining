// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IRewarder.sol";
interface IGovToken is IERC20 {
    function mint(address _to, uint _amount) external;
}
//Base masterchef code is taken from ConvexFinance
//Refactor and rewritten to work without SafeMath

contract HylMasterchef is Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IGovToken;

    mapping (uint => uint) public rewardsForPool;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of CVXs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accHylPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accHylPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. HYL to distribute per block.
        uint256 lastRewardBlock; // Last block number that CVXs distribution occurs.
        uint256 accHylPerShare; // Accumulated CVXs per share, times scale. See below.
        IRewarder rewarder;
    }

    //hyl
    IGovToken public hyl;
    // Block number when bonus HYL period ends.
    uint256 public bonusEndBlock;
    // HYL tokens created per block.
    uint256 public rewardPerBlock;
    // Bonus muliplier for early hyl makers.
    uint256 public constant BONUS_MULTIPLIER = 2;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when HYL mining starts.
    uint256 public startBlock;

    uint scale = 1e12;

    // Events
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user,  uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        IGovToken _hyl,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        hyl = _hyl;
        rewardPerBlock = _rewardPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        IRewarder _rewarder,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint += _allocPoint;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accHylPerShare: 0,
                rewarder: _rewarder
            })
        );
    }

    // Update the given pool's HYL allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        IRewarder _rewarder,
        bool _withUpdate,
        bool _updateRewarder
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = (totalAllocPoint - poolInfo[_pid].allocPoint) + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if(_updateRewarder){
            poolInfo[_pid].rewarder = _rewarder;
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return (_to - _from) * (BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to - _from;
        } else {
            return
                (bonusEndBlock-_from) * BONUS_MULTIPLIER + (_to - (bonusEndBlock));
        }
    }

    function _getReward(uint multiplier, uint rewardPerBlock,uint allocPoint,uint totalAlloc) internal view returns (uint256) {
        return (multiplier
                * (rewardPerBlock)
                 * (allocPoint))
                 / totalAlloc;
    }


    function _calculateBonus(uint256 _baseReward, uint256 _rewardsTotal) internal view returns (uint256) {
        //This boosts rewards based on profits
        return (((_baseReward  * scale) / _rewardsTotal) * _baseReward) / scale;
    }

    // View function to see pending CVXs on frontend.
    function pendingHyl(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accHylPerShare = pool.accHylPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 hylReward =_getReward(multiplier, rewardPerBlock, pool.allocPoint, totalAllocPoint); 
            accHylPerShare += (hylReward *scale) / (lpSupply);
        }
        uint256 baseReward =  ((user.amount *accHylPerShare) / (scale)) - (user.rewardDebt);
        uint256 bonusReward = _calculateBonus(baseReward, rewardsForPool[_pid]);
        return baseReward + bonusReward;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 hylReward =_getReward(multiplier, rewardPerBlock, pool.allocPoint, totalAllocPoint); 
        hyl.mint(address(this), hylReward);
        rewardsForPool[_pid] += hylReward;
        pool.accHylPerShare +=(hylReward *scale) / (lpSupply);
        pool.lastRewardBlock = block.number;
    }

    function _claimReward(PoolInfo storage _pool,UserInfo storage _user, address _to,uint _pid) internal {
        if (_user.amount > 0) {
            uint256 pending = ((_user.amount *_pool.accHylPerShare) / (scale)) - (_user.rewardDebt);
            safeRewardTransfer(_to, pending);
            rewardsForPool[_pid] -= pending;
            emit RewardPaid(msg.sender, _pid, pending);
        }
    }

    function _claimExtraReward(IRewarder _rewarder,uint _pid, address _to,UserInfo memory _user ) internal {
        if (address(_rewarder) != address(0)) {
            _rewarder.onReward(_pid, _to, _to, 0, _user.amount);
        }
    }

    function _processDeposit(PoolInfo memory _pool,address user,UserInfo storage _user , uint amount) internal {
        _pool.lpToken.safeTransferFrom(
            user,
            address(this),
            amount
        );
        _user.amount += amount;
        _user.rewardDebt = (_user.amount * _pool.accHylPerShare) / (scale);
    }

    function _processWithdraw(PoolInfo memory _pool,address user,UserInfo storage _user , uint amount) internal {
        _pool.lpToken.safeTransfer(
            user,
            amount
        );
        _user.amount -= amount;
        _user.rewardDebt = (_user.amount * _pool.accHylPerShare) / (scale);
    }

    // Deposit LP tokens to MasterChef for HYL allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        _claimReward(pool,user,msg.sender,_pid);
        _processDeposit(pool,msg.sender,user,_amount);
        //extra rewards
        _claimExtraReward(pool.rewarder,_pid,msg.sender,user);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        _claimReward(pool,user,msg.sender,_pid);
        _processWithdraw(pool,msg.sender,user,_amount);
        //extra rewards
        _claimExtraReward(pool.rewarder,_pid,msg.sender,user);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function claim(uint256 _pid, address _account) external{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_account];

        updatePool(_pid);
        _claimReward(pool,user,msg.sender,_pid);

        user.rewardDebt = (user.amount * pool.accHylPerShare) / (scale);

        //extra rewards
        _claimExtraReward(pool.rewarder,_pid,msg.sender,user);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        //TODO should emergency withdraw really claim extra rewards?
        //extra rewards
        _claimExtraReward(pool.rewarder,_pid,msg.sender,user);

    }

    function setRewardPerBlock(uint _newRewardPerBlock) external onlyOwner {
        rewardPerBlock = _newRewardPerBlock;
        massUpdatePools();
    }

    // Safe hyl transfer function, just in case if rounding error causes pool to not have enough CVXs.
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 hylBal = hyl.balanceOf(address(this));
        if (_amount > 0 && _amount > hylBal) {
            hyl.safeTransfer(_to, hylBal);
        } else if(_amount > 0){
            hyl.safeTransfer(_to, _amount);
        }
    }

}
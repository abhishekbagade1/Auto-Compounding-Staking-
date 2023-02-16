// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";


contract StakingRewards is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    IERC20Upgradeable public  rewardsToken; //0
    IERC20Upgradeable public  stakingToken;

    uint256 public reserve0;
    uint256 public reserve1;
   

    // Duration of rewards to be paid out (in seconds)
    uint256 public duration;
    // Timestamp of when the rewards finish
    uint256 public finishAt;
    // Minimum of last updated time and reward finish time
    uint256 public updatedAt;
    // Reward to be paid out per second
    uint256 public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint256 public rewardPerTokenStored;
    // User address => rewardPerTokenStored

    // Total staked
    uint public totalStaked;
    mapping(address => uint256) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public autoStakingPercntg;
    mapping(address=> UserDetails) public userDetailMap;
    // mapping(address => uint256) public amountStakedMap;
 
    // User address => staked amount
 mapping(address => uint256) public balanceOf;

 struct UserDetails{
    uint256 createdOn;
    uint256 depositId;
    uint256 initial_staking;
    uint256 current_staking;
    uint256 claimedRewards;  //user claimed rewards manually
    uint256 rewardsEarned;  // compunded rewards
    uint256 lastClaim;
 }

    function initialize  (address _stakingToken, address _rewardToken)public initializer {
        stakingToken = IERC20Upgradeable(_stakingToken);
        rewardsToken = IERC20Upgradeable(_rewardToken);

        __Ownable_init();
        __ReentrancyGuard_init_unchained();
        __Pausable_init();
   
    }

       modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    
    function stake(uint256 _amount, uint256 _autoStakingPercntg) external updateReward(_msgSender()) {
        require(_amount > 0, "amount = 0");

                UserDetails memory udetail = userDetailMap[_msgSender()];
        if(udetail.createdOn == 0){
         udetail.initial_staking = _amount ;
         udetail.current_staking = _amount;
         udetail.createdOn = block.timestamp;
        }else{
              udetail.current_staking += _amount;

        }
        userDetailMap[_msgSender()]= udetail;
        autoStakingPercntg[_msgSender()] = _autoStakingPercntg;
        totalStaked += _amount;
        stakingToken.transferFrom(_msgSender(), address(this), _amount);
    }
// if user wants to withdrwaw his rewards
    function withdrawFund(uint256 _amount) external updateReward(_msgSender()) {
            UserDetails memory udetail = userDetailMap[_msgSender()];
 uint256 amt = udetail.current_staking;
        require(_amount > 0, "amount = 0");
        require(amt > 0 , "No amount to Withdraw");
        
        udetail.current_staking -= _amount;
         userDetailMap[_msgSender()]= udetail;

        totalStaked -= _amount;
        rewardsToken.transfer(_msgSender(), _amount);
    }


// whole amount will be unstaked
    function Unstake(uint256 _depositId)public {
        UserDetails memory udetail = userDetailMap[_msgSender()];
        uint256 id = udetail.depositId;
        require(_depositId == id , "Invalid deposit Id");
        uint256 amt = udetail.current_staking;
        stakingToken.transfer(_msgSender(), amt);

    }

    function earned(address _account) public  returns (uint256) {
         uint256 asp= autoStakingPercntg[_account];

        uint256 a =( rewards[_account] * asp)/100 ;
        uint256 b = rewards[_account] - a;

        uint256 amt = swap(address(rewardsToken) , a);
        rewards[_account] = b;


        return
            (((balanceOf[_account] + amt )*
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }
//  rewardsToken    stakingToken

      function swap(address _rewardsToken, uint _amountIn) public  returns (uint amountOut) {
        require(
            _rewardsToken == address(rewardsToken) || _rewardsToken == address(stakingToken),
            "invalid token"
        );
        require(_amountIn > 0, "amount in = 0");

        bool isTokenRewdToken = _rewardsToken == address(rewardsToken);
        (IERC20Upgradeable rToken, IERC20Upgradeable sToken, uint reserveIn, uint reserveOut) = isTokenRewdToken
            ? (rewardsToken, stakingToken, reserve0, reserve1)
            : (stakingToken, rewardsToken, reserve1, reserve0);

        rToken.transferFrom(msg.sender, address(this), _amountIn);

        /*
        How much dy for dx?

        xy = k
        (x + dx)(y - dy) = k
        y - dy = k / (x + dx)
        y - k / (x + dx) = dy
        y - xy / (x + dx) = dy
        (yx + ydx - xy) / (x + dx) = dy
        ydx / (x + dx) = dy
        */
        // 0.3% fee
        uint amountInWithFee = (_amountIn * 997) / 1000;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        sToken.transfer(address(this), amountOut);

        _update(rewardsToken.balanceOf(address(this)), stakingToken.balanceOf(address(this)));
    }

     function _update(uint _reserve0, uint _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }



    
    function claimRewards() public  updateReward(_msgSender()) {
         UserDetails memory udetail = userDetailMap[_msgSender()];
        uint256 reward = rewards[_msgSender()];
        udetail.claimedRewards += reward;
        if (reward > 0) {
            rewards[_msgSender()] = 0;
            rewardsToken.transfer(_msgSender(), reward);
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalStaked;
    }


    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    function setRewardAmount(
        uint256 _amount
    ) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }


        require(rewardRate > 0, "reward rate = 0");
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "reward amount > balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function _min(uint256 x, uint256 y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}


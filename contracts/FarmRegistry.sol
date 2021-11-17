import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//@title MasterOwner
//@license MIT
//@author akshaynexus
//@version 1.0
//@notice FarmRegistry is a smart contract that manages available incentive budgets
contract FarmRegistry is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => uint) public incentivesAvailable;
    mapping(address => bool) public incentiveRefiller;
    mapping(address => bool) public incentiveClaimer;

    uint public totalIncentivesAvailable;

    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function toggleIncentiveRefiller(address _sender) public onlyOwner {
        incentiveRefiller[_sender] = !incentiveRefiller[_sender];
    }

    function toggleIncentiveClaimer(address _sender) public onlyOwner {
        incentiveClaimer[_sender] = !incentiveClaimer[_sender];
    }

    function refill(address vault, uint256 amount) public {
        require(incentiveRefiller[msg.sender],"!auth");
        incentivesAvailable[vault] += amount;
        totalIncentivesAvailable += amount;
    }

    function pullIncentivesFromVault(address vault, uint256 amount,address _to) public {
        require(incentiveClaimer[msg.sender],"!auth");
        require(incentivesAvailable[vault] >= amount && totalIncentivesAvailable >= amount,"exceeded");
        incentivesAvailable[vault] -= amount;
        totalIncentivesAvailable -= amount;
        token.safeTransfer(_to,amount);
    }

    function recoverToken(address _token) external onlyOwner {
        token = IERC20(_token);
        token.transfer(msg.sender,token.balanceOf(address(this)));
    }
}
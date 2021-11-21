// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


/// @author Premia
/// @title Primary Bootstrap Contribution
///        Allow users to contribute ONE to get a share of HYield equal to their percentage of total ONE contribution by the end of the PBC
contract HyieldPBC is Ownable {
    using SafeERC20 for IERC20;

    // The hyield token
    IERC20 public hyield;

    // The block at which PBC will start
    uint256 public startBlock;
    // The block at which PBC will end
    uint256 public endBlock;

    // The total amount of Premia for the PBC
    uint256 public hyieldTotal;
    // The total amount of eth collected
    uint256 public ethTotal;

    // The treasury address which will receive collected eth
    address payable public treasury;

    // Mapping of eth deposited by addresses
    mapping (address => uint256) public amountDeposited;
    // Mapping of addresses which already collected their Premia allocation
    mapping (address => bool) public hasCollected;

    ////////////
    // Events //
    ////////////

    event Contributed(address indexed user, uint256 amount);
    event Collected(address indexed user, uint256 amount);

    //////////////////////////////////////////////////
    //////////////////////////////////////////////////
    //////////////////////////////////////////////////

    /// @param _hyield The hyield token
    /// @param _startBlock The block at which the PBC will start
    /// @param _endBlock The block at which the PBC will end
    /// @param _treasury The treasury address which will receive collected eth
    constructor(IERC20 _hyield, uint256 _startBlock, uint256 _endBlock, address payable _treasury) {
        require(_startBlock < _endBlock, "EndBlock must be greater than StartBlock");
        hyield = _hyield;
        startBlock = _startBlock;
        endBlock = _endBlock;
        treasury = _treasury;
    }

    //////////////////////////////////////////////////
    //////////////////////////////////////////////////
    //////////////////////////////////////////////////

    ///////////
    // Admin //
    ///////////

    /// @notice Add hyield which will be distributed in the PBC
    /// @param _amount The amount of hyield to add to the PBC
    function addToken(uint256 _amount) external onlyOwner {
        require(block.number < endBlock, "PBC ended");

        hyield.safeTransferFrom(msg.sender, address(this), _amount);
        hyieldTotal += _amount;
    }

    /// @notice Send eth collected during the PBC, to the treasury address
    function sendEthToTreasury() external onlyOwner {
        treasury.transfer(address(this).balance);
    }

    function updateStartBlock(uint _block) public onlyOwner {
        startBlock = _block;
    }
    function updateEndBlock(uint _block) public onlyOwner {
        endBlock = _block;
    }

    function startPBC() public onlyOwner {
        updateStartBlock(block.number);
    }

    function endPBC() public onlyOwner {
        updateEndBlock(block.number);
    }

    function updateTreasury(address payable _treasury) public onlyOwner {
        treasury = _treasury;
    }

    //////////////////////////////////////////////////

    //////////
    // Main //
    //////////

    fallback() external payable {
        _contribute();
    }

    /// @notice Deposit ETH to participate in the PBC
    function contribute() external payable {
        _contribute();
    }

    /// @notice Deposit ETH to participate in the PBC
    function _contribute() internal {
        require(block.number >= startBlock, "PBC not started");
        require(msg.value > 0, "No eth sent");
        require(block.number < endBlock, "PBC ended");

        amountDeposited[msg.sender] += msg.value;
        ethTotal += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    function exitFromContrib() external {
        require(block.number < endBlock, "PBC Ended");
        uint amount = amountDeposited[msg.sender];
        require(amount > 0, "Address did not contribute");
        delete amountDeposited[msg.sender];
        delete hasCollected[msg.sender];
        ethTotal -= amount;
        payable(msg.sender).transfer(amount);
    }

    /// @notice Collect Premia allocation after PBC has ended
    function collect() external  {
        require(block.number > endBlock, "PBC not ended");
        require(hasCollected[msg.sender] == false, "Address already collected its reward");
        require(amountDeposited[msg.sender] > 0, "Address did not contribute");

        hasCollected[msg.sender] = true;
        uint256 contribution = (amountDeposited[msg.sender]* 1e12) /(ethTotal);
        uint256 hyieldAmount = (hyieldTotal*contribution) / (1e12);
        _safeTokenTransfer(msg.sender, hyieldAmount);
        emit Collected(msg.sender, hyieldAmount);
    }

    //////////////////////////////////////////////////

    //////////
    // View //
    //////////

    /// @notice Get the current hyield price (in eth)
    /// @return The current hyield price (in eth)
    function getPrice() external view returns(uint256) {
        return (ethTotal *1e18) / (hyieldTotal);
    }

    //////////////////////////////////////////////////

    //////////////
    // Internal //
    //////////////

    /// @notice Safe hyield transfer function, just in case if rounding error causes contract to not have enough PREMIAs.
    /// @param _to The address to which send hyield
    /// @param _amount The amount to send
    function _safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 hyieldBal = hyield.balanceOf(address(this));
        if (_amount > hyieldBal) {
            hyield.safeTransfer(_to, hyieldBal);
        } else {
            hyield.safeTransfer(_to, _amount);
        }
    }
}
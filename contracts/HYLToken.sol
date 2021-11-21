import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// @title HYL Token
// @version 1.0
// @author akshaynexus
// @license MIT
contract HYLToken is ERC20('HYield','HYL'), Ownable {
    // This keeps track of allowed minters of token
    mapping (address => bool) public minters;

    constructor()  {
        _mint(msg.sender, 10000 ether);
        minters[msg.sender] = true;
    }

    /**
    * @notice Toggles minter role for an account
    * @param _minter address of the account to toggle minter role
    * @return bool true if account is now a minter, false otherwise
    */
    function toggleMinter(address _minter) external onlyOwner returns (bool){
        require(_minter != address(0));
        minters[_minter] = !minters[_minter];
        return minters[_minter];
    }

    /**
    * @notice Mints HYL Token
    * @param _to address to mint to
    * @param _amount amount of HYL Token to mint
    * @return bool true if successful, false otherwise
    */
    function mint(address _to, uint _amount) external returns (bool){
        require(minters[msg.sender],"Only minters can mint");
        _mint(_to,_amount);
        return true;
    }

}

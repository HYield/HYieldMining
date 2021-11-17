import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// @title HYL Token
// @version 1.0
// @author akshaynexus
// @license MIT
contract HYLToken is ERC20('HYield','HYL'), Ownable {

    constructor()  {
        _mint(msg.sender, 10000 ether);
    }

    /**
    * @notice Mints HYL Token
    * @param _to address to mint to
    * @param _amount amount of HYL Token to mint
    */
    function mint(address _to, uint _amount) public onlyOwner {
        _mint(_to,_amount);
    }

}

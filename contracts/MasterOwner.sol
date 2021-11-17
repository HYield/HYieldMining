import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IVaultRegistry.sol";

interface IFarmRegistry {
    function refill(address vault, uint256 amount) external;
}
interface IOracle {
    function getPrice(address asset) external view returns (uint);
    function USDToGovToken(uint usd) external view returns (uint);
}

interface IGovToken {
    function mint(address _to, uint _amount) external;
}
interface IVault {
    function profitUncovered() external view returns (uint);
    function totalProfits() external view returns (uint);
    function token() external view returns (address);
    function recordProfitIncentiveCovered(uint) external;
}

//@title MasterOwner
//@license MIT
//@author akshaynexus
//@version 1.0

//@dev This contract is used to manage the inflation rate and the total supply of the gov token.
contract MasterOwner is Ownable {
    IOracle oracle;

    IGovToken token;

    IVaultRegistry vaultRegistry;
    IFarmRegistry farmRegistry;

    //Total USD worth of incentives minted
    uint incentivesMinted;

    /**
    * @notice Sets the vault registry contract,only the owner can call the setter
    * @param _registry Vault registry contract address
    */
    function setRegistry(address _registry) public onlyOwner {
        vaultRegistry = IVaultRegistry(_registry);
    }

    /**
    * @notice Sets the oracle contract,only the owner can call the setter
    * @param _oracle Oracle contract address
    */
    function setOracle(IOracle _oracle) public onlyOwner {
        oracle = _oracle;
    }

    /**
    * @notice Sets the gov token contract,only the owner can call the setter
    * @param _token Gov token contract address
    */
    function setToken(IGovToken _token) public onlyOwner {
        token = _token;
    }

    /**
    * @notice gets the total profits in usd
    * @return total profits in usd
    */
    function getTotalProfits() public view returns (uint256 total) {
        for(uint i=0;i<vaultRegistry.numReleases();i++){
            IVault vault = IVault(vaultRegistry.releases(i));
            uint profits = vault.totalProfits();
            uint profitsInUSD = ((profits * 1e18) * oracle.getPrice(vault.token())) / 1e18;
            total += profitsInUSD;
        }
    }

    /**
    * @notice gets the total incentives budget in usd
    * @return total incentives budget in usd
    */
    function getTotalIncentivesBudget() public view returns (uint256) {
        return getTotalProfits() / 10;
    }

    /**
    * @notice gets the price of hyl token in usd
    * @return uint price of hyl token in usd
    */
    function getPriceInUSD() public view returns (uint256) {
        oracle.getPrice(address(token));
    }

    /**
    * @notice Refills the hyl incentives for production vaults
    */
    function refillRewards() external onlyOwner {
        //This function is called by the owner to refill the incentives budget
        for(uint i=0;i<vaultRegistry.numReleases();i++){
            IVault vault = IVault(vaultRegistry.releases(i));

            uint profits = vault.profitUncovered();
            uint profitsInUSD = ((profits * 1e18) * oracle.getPrice(vault.token())) / 1e18;
            // total += profitsInUSD;

            uint incentivesToMint = oracle.USDToGovToken(profitsInUSD / 10);
            //Dev fee
            token.mint(owner(),incentivesToMint);
            // Incentives farm gets the rest
            token.mint(address(farmRegistry),incentivesToMint);
            farmRegistry.refill(address(vault),incentivesToMint);
            vault.recordProfitIncentiveCovered(profits);
        }
    }

    function getTotalRewards() public view returns (uint256) {
        //This returns the total rewards in HYL Tokens
    }

}
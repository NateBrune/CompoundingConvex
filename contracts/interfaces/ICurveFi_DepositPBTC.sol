abstract contract ICurveFi_DepositPBTC{
    function add_liquidity(uint256[2] calldata uamounts, uint256 min_mint_amount) virtual external returns (uint256);
    function remove_liquidity(uint256 _amount, uint256[4] calldata min_uamounts) virtual external;
    function remove_liquidity_imbalance(uint256[4] calldata uamounts, uint256 max_burn_amount) virtual external;

    function coins(int128 i) virtual external view returns (address);
    function underlying_coins(int128 i) virtual external view returns (address);
    function underlying_coins() virtual external view returns (address[4] memory);
    function curve() virtual external view returns (address);
    function token() virtual external view returns (address);
}
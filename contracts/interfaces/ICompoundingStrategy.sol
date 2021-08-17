pragma solidity ^0.8.0;
// Allows anyone to claim a token if they exist in a merkle root.
interface ICompoundingStrategy {

    // Returns virtual price of strategy token.
    function virtualPrice() external view returns (uint256);

    // Harvest function sells all rewards tokens, reinvests into pool token, and stakes them in guage.
    function harvest() external;

    // Deposit into stategy with pool token.
    function deposit(uint256 amount) external;

    // Deposit whole user pool token balance into strategy.
    function depositAll() external;

    // Withdraw into stategy with pool token.
    function withdraw(uint256 amount) external;

    // Withdraw whole user pool token balance into strategy.
    function withdrawAll() external;

    // This event is triggered whenever a call to deposit succeeds.
    event Deposit(uint256 index, address account, uint256 amount);

    // This event is triggered whenever a called to withdraw succeeds.
    event Withdraw(address account, uint256 claimed);

    // This event is called when a call to harvest succeeds.
    event Harvest(address account, uint256 claimed);
}
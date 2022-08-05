// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Roulette {

    address private _owner;

    enum RouletteResult{ AVAX, BTC, SOL }

    struct RoundInfo {
        bool isFinished;
        RouletteResult result;
        uint256 totalBetted;
        mapping(RouletteResult => uint256) totalBettedByResult;
        mapping(address => mapping (RouletteResult => uint256)) betByAddress;
        uint256 rewarded;
    }

    mapping (address => mapping (uint256 => bool)) public isClaimed;

    mapping(uint256 => Round) public rounds;

    uint256 public currentRoundId;

    uint256 public totalDeposited;
    uint256 public rewardPool;
    mapping(address => uint256) depositByAddress;

    uint256 public poolFee;
    uint256 public totalFee;

    uint256 public constant ONE_HUNDRED = 100;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
        poolFee = 10;
    }

    function setTicketPrice(uint256 price) public onlyOwner {
        _ticket_price = price;
    }

    function bet(RouletteResult betOption) payable external {
        RoundInfo storage currentRound = rounds[currentRoundId];
        currentRound.betByAddress[msg.sender][betOption] += msg.value;
        currentRound.totalBettedByResult[betOption] += msg.value;
        currentRound.totalBetted += msg.value;
    }

    function deposit() payable external {
        totalDeposited += msg.value;
        rewardPool += msg.value;
        depositByAddress[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 userDeposited = depositByAddress[msg.sender];
        require(userDeposited, "You did NOT deposited!");
        depositByAddress[msg.sender] = 0;
        uint256 withdrawAmount = userDeposited * rewardPool / totalDeposited;
        totalDeposited -= withdrawAmount;
        rewardPool -= withdrawAmount;
        uint256 feeing = withdrawAmount / ONE_HUNDRED;
        totalFee += feeing;
        withdrawAmount -= feeing;
        (bool sent, ) = address(msg.sender).call{value: withdrawAmount}("");
        require(sent, "Sendout reward failed!");
        
        emit Withdrawed(msg.sender, withdrawAmount)
    }

    function roll() onlyOwner external {
        RoundInfo storage currentRound = rounds[currentRoundId];
        uint256 lastRound = currentRoundId;
        currentRoundId += 1;
        currentRound.isFinished = true;
        currentRound.result = RouletteResult(_random());
        rewardPool += currentRound.totalBetted;
        if (currentRound.result == RouletteResult.BTC) {
            currentRound.rewarded = currentRound.totalBettedByResult[RouletteResult.BTC] * 10;
        } else {
            currentRound.rewarded = currentRound.totalBettedByResult[currentRound.result] * 2;
        }
        if (currentRound.rewarded >= rewardPool) {
            currentRound.rewarded = rewardPool;
        }
        rewardPool -= currentRound.rewarded;
        uint256 feeing = currentRound.rewarded * poolFee / ONE_HUNDRED;
        currentRound.rewarded -= feeing;
        totalFee += feeing;
        
        emit Rolled(lastRound, currentRound.result, currentRound.rewarded, feeing);
    }

    function claimReward(uint256 roundId) external {
        RoundInfo storage thisRound = rounds[roundId];
        require(!isClaimed[msg.sender][roundId], "You already claimed!");
        uint256 userBetted = thisRound.betByAddress[msg.sender][thisRound.result];
        require(userBetted > 0, "Not Bet on this result ;))");
        uint256 claiming = userBetted * thisRound.rewarded / thisRound.totalBettedByResult;
        (bool sent, ) = address(msg.sender).call{value: claiming}("");
        require(sent, "Sendout reward failed!");
        
        emit Claimed(roundId, msg.sender, claiming);
    }

    function setFee(uint fee) public onlyOwner {
        require(fee < 100, "Setting Fee: invalid fee");
        poolFee = fee;
    }

    function _random() private view returns (uint){
        return uint(keccak256(abi.encodePacked(gasLeft(),block.timestamp, block.difficulty, msg.sender))) % 3;
    }

    function getRoundInfo(uint round_index) public view returns(uint, uint256, uint, uint256, uint, uint) {
        Round memory round = rounds[round_index];
        return (round_index, round.start_time, round.result, round.ticket_price, round.amount_h, round.amount_t);
    }

    function withdraw(uint256 amount) public payable onlyOwner {
        require(_pool_balance >= amount, "Balance: not enought");
        payable(msg.sender).transfer(amount);
        _pool_balance = _pool_balance - amount;
    }

    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function aggregate(Call[] memory calls) public onlyOwner returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success, "Multicall aggregate: call failed");
            returnData[i] = ret;
        }
    }
}

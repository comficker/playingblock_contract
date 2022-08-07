// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ILottery {
    function donate() external payable;
}

contract CoinFlipper {
    event Created(uint _index, address _left, uint _resultIn, uint256 _amount);
    event Completed(uint _index, address _right, address _winner, uint _resultOut);

    struct Round {
        uint fee;
        uint resultIn;
        uint resultOut;
        uint256 amount;
        address left;
        address right;
    }

    uint public poolFee = 10;
    uint public lastRoundIndex = 0;
    uint[] public activeRounds;
    address private _owner;
    address private _receiver;
    Round[] private rounds;
    mapping(address => address) public _refs;
    mapping(address => uint) public _refFees;
    mapping(address => uint) public _refCount;
    mapping(address => uint) public _refClaimed;

    ILottery public lottery;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor(ILottery lottery_interface) {
        _owner = msg.sender;
        _receiver = msg.sender;
        lottery = lottery_interface;
    }

    function setFee(uint fee) public onlyOwner {
        require(fee < 100, "Feed: invalid");
        poolFee = fee;
    }

    function updateLottery(ILottery lottery_interface) external onlyOwner {
        lottery = lottery_interface;
    }

    function setReceiver(address receiver) public onlyOwner {
        _receiver = receiver;
    }

    function random() private view returns (uint){
        return uint(keccak256(abi.encodePacked(gasleft(), block.timestamp, block.difficulty, msg.sender))) % 2;
    }

    function create(uint resultIn, address ref) public payable {
        require(msg.value > 0, "Round: ammout is zero");
        require(resultIn == 0 || resultIn == 1, "Round: invalid value");
        if (ref != address(0) && _refs[msg.sender] == address(0) && ref != msg.sender) {
            _refs[msg.sender] = ref;
            _refCount[ref]++;
        }
        rounds.push();
        Round storage round = rounds[lastRoundIndex];
        round.left = msg.sender;
        round.amount = msg.value;
        round.resultIn = resultIn;
        round.fee = poolFee;
        activeRounds.push(lastRoundIndex);
        lastRoundIndex++;
        emit Created(lastRoundIndex, msg.sender, resultIn, round.amount);
    }

    function cancel(uint roundIndex) public payable {
        Round storage round = rounds[roundIndex];
        require(msg.sender == round.left, "Round: not owner");
        require(round.right == address(0), "Round: completed"); // require when user can cancel a finished round!;
        uint fee = round.amount * round.fee / 100;
        _refFees[_receiver] = _refFees[_receiver] + fee;
        round.right = msg.sender;
        for (uint i = 0; i < activeRounds.length; i++) {
            if (activeRounds[i] == roundIndex) {
                activeRounds[i] = activeRounds[activeRounds.length - 1];
                activeRounds.pop();
                break;
            }
        }
        payable(round.left).transfer(round.amount - fee);
        emit Completed(roundIndex, msg.sender, msg.sender, round.resultOut);
    }

    function bet(uint roundIndex, address ref) public payable {
        require(msg.sender == tx.origin, "This should come from you and you!"); // anti cheat from contract
        Round storage round = rounds[roundIndex];
        require(address(0) != round.left, "Round: not started");
        require(address(0) == round.right, "Round: completed");
        require(msg.sender != round.left, "Round: bet yourself");
        require(round.amount == msg.value, "Round: amount not match");
        if (ref != address(0) && _refs[msg.sender] == address(0) && ref != msg.sender) {
            _refs[msg.sender] = ref;
            _refCount[ref]++;
        }
        uint rs = random();
        uint fee = round.amount * round.fee / 100;
        address winner;
        round.right = msg.sender;
        round.resultOut = rs;
        if (round.resultIn == rs) {
            winner = round.left;
            payable(round.left).transfer(round.amount + round.amount - fee);
        } else {
            winner = round.right;
            payable(round.right).transfer(round.amount + round.amount - fee);
        }
        for (uint i = 0; i < activeRounds.length; i++) {
            if (activeRounds[i] == roundIndex) {
                activeRounds[i] = activeRounds[activeRounds.length - 1];
                activeRounds.pop();
                break;
            }
        }
        if (_refs[winner] != address(0)) {
            _refFees[_refs[winner]] = _refFees[_refs[winner]] + fee / 5;
            fee = fee - fee / 5;
        }
        uint256 donating = fee / 2;
        lottery.donate{value: donating}();
        _refFees[_receiver] = _refFees[_receiver] + (fee - donating);
        emit Completed(roundIndex, msg.sender, winner, rs);
    }

    function getActiveRounds() public view returns(uint[] memory) {
        return activeRounds;
    }

    function getRoundInfo(uint roundIndex) public view returns(uint, address, address, uint, uint, uint256) {
        Round storage round = rounds[roundIndex];
        return (roundIndex, round.left, round.right, round.resultIn, round.resultOut, round.amount);
    }

    function claim() public payable {
        _refClaimed[msg.sender] = _refClaimed[msg.sender] + _refFees[msg.sender];
        _refFees[msg.sender] = 0;
        payable(msg.sender).transfer(_refFees[msg.sender]);
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

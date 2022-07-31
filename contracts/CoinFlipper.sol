// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

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


    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
        _receiver = msg.sender;
    }

    function setFee(uint fee) public onlyOwner {
        require(fee < 100, "Feed: invalid");
        poolFee = fee;
    }

    function setReceiver(address receiver) public onlyOwner {
        _receiver = receiver;
    }

    function random() private view returns (uint){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender))) % 2;
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
        uint fee = round.amount * round.fee / 100;
        _refFees[_receiver] = _refFees[_receiver] + fee;
        payable(round.left).transfer(round.amount - fee);
        round.right = msg.sender;
        for (uint i = 0; i < activeRounds.length; i++) {
            if (activeRounds[i] == roundIndex) {
                activeRounds[i] = activeRounds[activeRounds.length - 1];
                activeRounds.pop();
                break;
            }
        }
        emit Completed(roundIndex, msg.sender, msg.sender, round.resultOut);
    }

    function bet(uint roundIndex, address ref) public payable {
        Round storage round = rounds[roundIndex];
        require(address(0) != round.left, "Round: not started");
        require(address(0) == round.right, "Round: completed");
        require(msg.sender != round.left, "Round: bet yourself");
        require(round.amount == msg.value, "Round: amout not match");
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
        _refFees[_receiver] = _refFees[_receiver] + fee;
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
        payable(msg.sender).transfer(_refFees[msg.sender]);
        _refClaimed[msg.sender] = _refClaimed[msg.sender] + _refFees[msg.sender];
        _refFees[msg.sender] = 0;
    }
}

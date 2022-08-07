// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Lottery {
    event RoundDraw(uint _roundIndex, address winner, uint result, uint prize);
    event TicketBought(uint _roundIndex, address buyer, uint[] nums, uint[] success);

    uint public ticketPrice = 100000000 gwei;
    uint public poolFee = 10;
    uint public currentRound = 0;

    address private _owner;
    address private _receiver;
    mapping(address => address) refs;

    struct Round {
        uint fee;
        uint ticketPrice;
        mapping(uint => address) owners;
        mapping(address => uint[]) balances;
        uint timeDraw;
        uint result;
        uint prize;
    }

    Round[] rounds;


    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function setFee(uint fee) public onlyOwner {
        require(fee < 100, "Feed: invalid");
        poolFee = fee;
    }

    function setReceiver(address receiver) public onlyOwner {
        _receiver = receiver;
    }

    function setTicketPrice(uint price) public onlyOwner {
        ticketPrice = price;
    }

    function random() public view returns (uint){
        Round storage r = rounds[currentRound];
        return 111111 + uint(
            keccak256(
                abi.encodePacked(block.timestamp, block.difficulty, msg.sender, rounds.length, r.prize)
            )
        ) % 888888;
    }

    constructor() {
        _owner = msg.sender;
        _receiver = msg.sender;
        rounds.push();
        Round storage r = rounds[currentRound];
        r.fee = poolFee;
        r.ticketPrice = ticketPrice;
        r.timeDraw = block.timestamp + 1 days;
    }

    function donate() public payable {
        Round storage r = rounds[currentRound];
        r.prize += msg.value;
    }

    function buyTicket(uint[] memory nums, address ref) public payable {
        Round storage r = rounds[currentRound];
        require(msg.value == nums.length * r.ticketPrice, "balance: invalid input");
        refs[msg.sender] = ref;
        uint[] memory success = nums;
        uint countFail = 0;
        for (uint i = 0; i < nums.length; i++) {
            if (r.owners[nums[i]] == address(0) && nums[i] >= 111111 && nums[i] < 999999) {
                r.owners[nums[i]] = msg.sender;
                r.balances[msg.sender].push(nums[i]);
                r.prize = r.prize + msg.value;
            } else {
                success[i] = 0;
                countFail++;
            }
        }
        if (countFail > 0) {
            payable(msg.sender).transfer(countFail * r.fee);
        }
        emit TicketBought(currentRound, msg.sender, nums, success);
    }

    function draw() public onlyOwner {
        Round storage r = rounds[currentRound];
        address winner;
        uint rs = random();
        if (r.owners[rs] != address(0)) {
            winner = r.owners[rs];
            currentRound++;
            rounds.push();
            Round storage next = rounds[currentRound];
            next.fee = poolFee;
            next.ticketPrice = ticketPrice;
            next.timeDraw = block.timestamp + 1 days;
            payable(winner).transfer(r.prize);
        } else {
            r.timeDraw = block.timestamp + 1 days;
        }
        r.result = rs;
        emit RoundDraw(currentRound, winner, rs, r.prize);
    }

    function getRoundInfo(uint roundIndex) public view returns(uint,uint, uint, uint, uint, uint) {
        Round storage r = rounds[roundIndex];
        return (roundIndex, r.ticketPrice, r.fee, r.timeDraw, r.result, r.prize);
    }

    function getCurrentRound() public view returns(uint,uint, uint, uint, uint, uint) {
        Round storage r = rounds[currentRound];
        return (currentRound, r.ticketPrice, r.fee, r.timeDraw, r.result, r.prize);
    }

    function getBalances(uint roundIndex) public view returns(uint[] memory) {
        Round storage r = rounds[roundIndex];
        return r.balances[msg.sender];
    }

    function validNumber(uint roundIndex, uint num) public view returns(bool) {
        Round storage r = rounds[roundIndex];
        return r.owners[num] != address(0);
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
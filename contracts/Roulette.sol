// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Roulette {
    event Bet(address indexed _player, uint _value, uint _ticket);
    event Flipping(uint256 _round, uint _result);

    struct Ticket {
        bool withdraw;
        uint amount_h;
        uint amount_t;
    }

    struct Round {
        uint256 start_time;
        uint256 ticket_price;
        bool complete;
        mapping(address => Ticket) tickets;
        uint result;
        uint fee;
        uint amount_h;
        uint amount_t;
    }

    address private _owner;
    uint256 public _pool_balance;
    uint256 public _ticket_price;
    uint256 public _current_round;
    uint public _pool_fee = 10;
    Round[] private rounds;
    bool _is_betting;
    mapping(address => uint256[]) public _joined_rounds;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
        _is_betting = true;
        _ticket_price = 10000000 gwei;
        _current_round = 0;
        rounds.push();
        Round storage round = rounds[_current_round];
        round.start_time = block.timestamp;
        round.fee = _pool_fee;
        round.ticket_price = _ticket_price;
    }

    function setTicketPrice(uint256 price) public onlyOwner {
        _ticket_price = price;
    }

    function setFee(uint fee) public onlyOwner {
        require(fee < 100, "Feed: invalid");
        _pool_fee = fee;
    }

    function random() private view returns (uint){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender))) % 2;
    }

    function bet(uint number, uint ticket) public payable {
        Round storage round = rounds[_current_round];
        require(round.start_time + 15 minutes > block.timestamp, "Round: timeout");
        require(ticket * _ticket_price == msg.value, "Round: not enought money");
        uint amount = ticket;
        if (round.tickets[msg.sender].amount_t == 0 && round.tickets[msg.sender].amount_h == 0) {
            _joined_rounds[msg.sender].push(_current_round);
        }
        if (number == 0) {
            round.amount_t = round.amount_t + amount;
            round.tickets[msg.sender].amount_t = round.tickets[msg.sender].amount_t + amount;
        } else {
            round.amount_h = round.amount_h + amount;
            round.tickets[msg.sender].amount_h = round.tickets[msg.sender].amount_h + amount;
        }

        _pool_balance = _pool_balance + msg.value;
        emit Bet(msg.sender, number, ticket);
    }

    function flip() public onlyOwner {
        // DAO
        // get result
        uint rs = random();
        Round storage round = rounds[_current_round];
        round.result = rs;
        round.complete = true;
        _current_round = _current_round + 1;
        //  create new round
        rounds.push();
        Round storage round2 = rounds[_current_round];
        round2.start_time = block.timestamp + 1 minutes;
        round2.fee = _pool_fee;
        round2.ticket_price = _ticket_price;
        emit Flipping(_current_round - 1, rs);
    }

    function getBooty(uint round_index, address wallet) public view returns(uint256) {
        Round storage round = rounds[round_index];
        if (round.tickets[wallet].withdraw) {
            return 0;
        }
        uint256 balance = 0;
        if (round.result == 0) {
            if (round.amount_t > 0) {
                balance = balance + _ticket_price * round.tickets[wallet].amount_t;
                balance = balance + _ticket_price * round.tickets[wallet].amount_t * round.amount_h / round.amount_t;
            }
        } else {
            if (round.amount_h > 0) {
                balance = balance + _ticket_price * round.tickets[wallet].amount_h;
                balance = balance + _ticket_price * round.tickets[wallet].amount_h * round.amount_t / round.amount_h;
            }
        }
        return balance - balance * round.fee / 100;
    }

    function getBooties(address wallet) public view returns(uint256 balance) {
        uint256[] storage joined_rounds = _joined_rounds[wallet];
        for (uint256 i = 0; i < joined_rounds.length; i++) {
            Round storage round = rounds[joined_rounds[i]];
            uint256 round_balance = 0;
            if (!round.tickets[wallet].withdraw) {
                if (round.result == 0) {
                    if (round.amount_t > 0) {
                        round_balance = round_balance + _ticket_price * round.tickets[wallet].amount_t;
                        round_balance = round_balance + _ticket_price * round.tickets[wallet].amount_t * round.amount_h / round.amount_t;
                    }
                } else {
                    if (round.amount_h > 0) {
                        round_balance = round_balance + _ticket_price * round.tickets[wallet].amount_h;
                        round_balance = round_balance + _ticket_price * round.tickets[wallet].amount_h * round.amount_t / round.amount_h;
                    }
                }
                round_balance = round_balance - round_balance * round.fee / 100;
            }
            balance = balance + round_balance;
        }
        return balance;
    }

    function claimBooty(uint round_index) public payable {
        Round storage round = rounds[round_index];
        Ticket storage ticket = round.tickets[msg.sender];
        require(!ticket.withdraw, "Ticket: withdrawn");
        uint256 balance = 0;
        if (round.result == 0) {
            if (round.amount_t > 0) {
                balance = balance + _ticket_price * ticket.amount_t;
                balance = balance + _ticket_price * ticket.amount_t * round.amount_h / round.amount_t;
            }
        } else {
            if (round.amount_h > 0) {
                balance = balance + _ticket_price * ticket.amount_h;
                balance = balance + _ticket_price * ticket.amount_h * round.amount_t / round.amount_h;
            }
        }
        balance = balance - balance * round.fee / 100;
        require(balance > 0, "Ticket: booty is zero");
        require(_pool_balance >= balance , "Pool: not enought");
        uint256[] storage joined_rounds = _joined_rounds[msg.sender];
        for (uint256 i = 0; i < joined_rounds.length; i++) {
            if (joined_rounds[i] == round_index) {
                joined_rounds[i] = joined_rounds[joined_rounds.length - 1];
                joined_rounds.pop();
                break;
            }
        }
        _pool_balance = _pool_balance - balance;
        payable(msg.sender).transfer(balance);
        ticket.withdraw = true;
    }

    function claimBooties() public payable {
        uint256[] storage joined_rounds = _joined_rounds[msg.sender];
        uint256 total = 0;
        for (uint256 i = 0; i < joined_rounds.length; i++) {
            Round storage round = rounds[joined_rounds[i]];
            Ticket storage ticket = round.tickets[msg.sender];
            if (!ticket.withdraw) {
                uint256 balance = 0;
                if (round.result == 0) {
                    if (round.amount_t > 0) {
                        balance = balance + _ticket_price * ticket.amount_t;
                        balance = balance + _ticket_price * ticket.amount_t * round.amount_h / round.amount_t;
                    }
                } else {
                    if (round.amount_h > 0) {
                        balance = balance + _ticket_price * ticket.amount_h;
                        balance = balance + _ticket_price * ticket.amount_h * round.amount_t / round.amount_h;
                    }
                }
                ticket.withdraw = true;
                total = total + balance - balance * round.fee / 100;
            }

        }
        require(total > 0, "Ticket: booty is zero");
        require(_pool_balance >= total , "Pool: not enought");
        payable(msg.sender).transfer(total);
        _pool_balance = _pool_balance - total;
        delete _joined_rounds[msg.sender];
    }

    function getRoundInfo(uint round_index) public view returns(uint, uint256, uint, uint256, uint, uint) {
        Round storage round = rounds[round_index];
        return (round_index, round.start_time, round.result, round.ticket_price, round.amount_h, round.amount_t);
    }

    function withdraw(uint256 amount) public payable onlyOwner {
        require(_pool_balance >= amount, "Balance: not enought");
        payable(msg.sender).transfer(amount);
        _pool_balance = _pool_balance - amount;
    }
}

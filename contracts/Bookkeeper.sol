pragma solidity ^0.4.0;

// ABI for our oracle
contract Oracle{
	function update(bytes32 newCurrent) public;
	function current()constant public returns(bytes32);
}

contract Bookkeeper{

    // Owner (creator) of the contract
    address owner;
    // Bidding closing time
    uint public electionEnd;
    // Set to true when election is over winnings has been calculated
    bool public finalized;
    // Address of our oracle
    address chainlink = 0x66DDa0e893A330Cb6c693Ed7a01f392eB1B9De88;
    Oracle oracle = Oracle(chainlink);
    // Outcome of the election. Set after election is over
    bool public outcome;
    
    // Participant addresses
    address[] participantsAddresses;
    // Participants' bets
    mapping(address => uint256) bets;
    // Participants selected outcome
    mapping(address => bool) participantOutcome;
    // Total bets for false and true outcome
    mapping(bool => uint256) totalBets;
    
    // The ratios for the two outcomes to be used when calculating winnings 
    // Actual ratio * 100
    // Ratio to be used when outcome = 0
    mapping(bool => uint256) ratio;
        
    /// Election is over
    modifier electionOver() {
        require(!finalized);
        require(now >= electionEnd);
        _;
    }
    
    /// Taking bets
    modifier betsOpen() {
        require(now < electionEnd);
        _;
    }
    
    /// Election is over and ratio for winners has been set
    modifier bookFinalized() {
        require(finalized);
        _;
    }
    
    /// Participant is a winner if he bet on the outcome returned from the oracle
    modifier isWinner(address _participant) {
        require(participantOutcome[_participant] == outcome);
        _;
    }
    
    
    /// Create a bookkeeper for election
    /// `_timeToBid` blocks until election closes
    function Bookkeeper() public{
        // Set owner to the person who created the contract
        owner = msg.sender;
        
        // Set the time we stop taking bets
        electionEnd = now + 10; // TODO 10 should be seconds for bidding
    }
    
    /// Read value from chainlink contract and output
    function read() public constant returns (bytes32) {
        // Read value from oracle
        bytes32 answer = oracle.current();
        return answer;
    }

    /// Participate in the bet and stake your ether
    function bet(bool _outcome) public payable returns (bool) {
        // Make sure the election hasn't completed yet
        //require(now < electionEnd);
        
        // Require a stake of at least 1 wei
        require(msg.value >= 1);
        
        // Only one bet per address
        require(bets[msg.sender] == 0);
        
        // Store the participant in the participants array
        bets[msg.sender] += msg.value;
        
        // Update total for the chosen outcome
        totalBets[_outcome] += msg.value;
        
        // Update participant outcome
        participantOutcome[msg.sender] = _outcome;
        
        return true;
    }
    
    /// Check your bet amount
    function checkBet() public view returns (uint256) {
        return bets[msg.sender];
    }
    
    /// Withdraw winnings after election is over
    function withdraw() isWinner(msg.sender) bookFinalized public returns (bool) {
        // Make sure participant has bet of more than 0 wei
        require(bets[msg.sender] > 0);
        
        // Save the size of the bet
        uint256 amount = bets[msg.sender];
        
        // Set bet value to zero to while trying send
        // to prevent multiple withdrawals of same bet
        bets[msg.sender] = 0;
        // 
        if (!msg.sender.send(div(mul(amount, ratio[outcome]), 100))) {
            // Send failed, set the bet value back to what it was
            bets[msg.sender] = amount;
            return false;
        }
        
        // Withdrawal succeeded
        return true;
    }
    
    /// Check result of election and calculate ratio of winnings/losses * 100
    function finalize() electionOver public returns (bool) {
        // Set the outcome of the election
        
        // TODO change to this when readong from oracle
        //outcome = oracle.current() == bytes32(1);
        // for debugging
        outcome = true;
        // If either side has no participants the ratio is always 100
        // which means winners get exactly the amount they bet back
        if (totalBets[true] == 0 || totalBets[false] == 0) {
            ratio[true] = 100;
            ratio[false] = 100;
        }
        else {
            // Make sure there are bets on both sides
            assert(totalBets[false] > 0 && totalBets[true] > 0);
            // Calculate returns for winner. Total bets for both outcomes
            // divided by total bets for winners gives the ratio. 
            // multiply by 100 because we are only using integers.
            // withdrawals will be divided by 100 in the withdraw function
            ratio[outcome] = div(mul(totalBets[outcome] + totalBets[!outcome], 100), totalBets[outcome]);
        }
        finalized = true;
        return true;
    }
    
    /// Multiple of two numbers
      function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
          return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }
  
    /// Integer division of two numbers, truncating the quotient.
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
  }
}

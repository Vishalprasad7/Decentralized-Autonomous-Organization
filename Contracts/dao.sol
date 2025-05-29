// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Autonomous Organization (DAO)
 * @dev A simple DAO contract that allows token holders to create proposals, vote, and execute decisions
 */
contract Project {
    // Struct to represent a proposal
    struct Proposal {
        uint256 id;
        string description;
        uint256 amount;
        address payable recipient;
        uint256 votes;
        uint256 deadline;
        bool executed;
        mapping(address => bool) voters;
    }

    // State variables
    address public owner;
    mapping(address => uint256) public stakeholders;
    mapping(uint256 => Proposal) public proposals;
    uint256 public numProposals;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant QUORUM = 50; // 50% quorum required
    uint256 public totalStakes;

    // Events
    event ContributionReceived(address contributor, uint256 amount);
    event ProposalCreated(uint256 proposalId, string description, address recipient, uint256 amount);
    event Voted(uint256 proposalId, address voter, uint256 votes);
    event ProposalExecuted(uint256 proposalId, address recipient, uint256 amount);

    // Modifiers
    modifier onlyStakeholder() {
        require(stakeholders[msg.sender] > 0, "Not a stakeholder");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Core Function 1: Contribute to the DAO and become a stakeholder
     * @notice Send ETH to become a stakeholder with voting power
     */
    function contribute() external payable {
        require(msg.value > 0, "Contribution must be greater than 0");
        
        stakeholders[msg.sender] += msg.value;
        totalStakes += msg.value;
        
        emit ContributionReceived(msg.sender, msg.value);
    }

    /**
     * @dev Core Function 2: Create a new proposal
     * @param _description Description of the proposal
     * @param _recipient Address to receive funds if proposal passes
     * @param _amount Amount of ETH to transfer if proposal passes
     */
    function createProposal(
        string memory _description,
        address payable _recipient,
        uint256 _amount
    ) external onlyStakeholder {
        require(_amount <= address(this).balance, "Insufficient DAO balance");
        require(_recipient != address(0), "Invalid recipient address");
        require(bytes(_description).length > 0, "Description cannot be empty");

        uint256 proposalId = numProposals;
        Proposal storage newProposal = proposals[proposalId];
        
        newProposal.id = proposalId;
        newProposal.description = _description;
        newProposal.amount = _amount;
        newProposal.recipient = _recipient;
        newProposal.votes = 0;
        newProposal.deadline = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;

        numProposals++;
        
        emit ProposalCreated(proposalId, _description, _recipient, _amount);
    }

    /**
     * @dev Core Function 3: Vote on a proposal
     * @param _proposalId ID of the proposal to vote on
     */
    function vote(uint256 _proposalId) external onlyStakeholder {
        require(_proposalId < numProposals, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.deadline, "Voting period has ended");
        require(!proposal.voters[msg.sender], "Already voted on this proposal");
        require(!proposal.executed, "Proposal already executed");

        uint256 voterStake = stakeholders[msg.sender];
        proposal.votes += voterStake;
        proposal.voters[msg.sender] = true;

        emit Voted(_proposalId, msg.sender, voterStake);

        // Auto-execute if quorum is reached
        if (proposal.votes >= (totalStakes * QUORUM) / 100) {
            executeProposal(_proposalId);
        }
    }

    /**
     * @dev Execute a proposal if it has enough votes and hasn't expired
     * @param _proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 _proposalId) public {
        require(_proposalId < numProposals, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.votes >= (totalStakes * QUORUM) / 100, "Insufficient votes");
        require(address(this).balance >= proposal.amount, "Insufficient contract balance");

        proposal.executed = true;
        proposal.recipient.transfer(proposal.amount);

        emit ProposalExecuted(_proposalId, proposal.recipient, proposal.amount);
    }

    /**
     * @dev Get proposal details
     * @param _proposalId ID of the proposal
     */
    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 amount,
        address recipient,
        uint256 votes,
        uint256 deadline,
        bool executed
    ) {
        require(_proposalId < numProposals, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.amount,
            proposal.recipient,
            proposal.votes,
            proposal.deadline,
            proposal.executed
        );
    }

    /**
     * @dev Check if an address has voted on a specific proposal
     */
    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        require(_proposalId < numProposals, "Invalid proposal ID");
        return proposals[_proposalId].voters[_voter];
    }

    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Get stakeholder's voting power
     */
    function getVotingPower(address _stakeholder) external view returns (uint256) {
        return stakeholders[_stakeholder];
    }

    /**
     * @dev Emergency function to withdraw funds (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // Allow contract to receive ETH directly
    receive() external payable {
        require(msg.value > 0, "Contribution must be greater than 0");
        
        stakeholders[msg.sender] += msg.value;
        totalStakes += msg.value;
        
        emit ContributionReceived(msg.sender, msg.value);
    }
}

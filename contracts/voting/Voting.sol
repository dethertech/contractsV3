pragma solidity ^0.8.1;
pragma experimental ABIEncoderV2;

import "./DthWrapper.sol";
import "../interfaces/IProtocolController.sol";
import "../libraries/SharedStructs.sol";

contract Voting {

    // ------------------------------------------------
    //
    // Enums
    //
    // ------------------------------------------------

    enum VoterState {Absent, Yea, Nay}
    enum ProposalKind { GlobalParams, CountryFloorPrice, SendDth }

    // ------------------------------------------------
    //
    // Structs
    //
    // ------------------------------------------------

    struct Proposal {
        bool executed;
        uint64 startDate;
        uint64 snapshotBlock;
        uint64 supportRequiredPct;
        uint64 minAcceptQuorumPct;
        uint256 yea;
        uint256 nay;
        uint256 votingPower;
        bytes args;
        ProposalKind kind;
        mapping(address => VoterState) voters;
    }

    // ------------------------------------------------
    //
    // Variables
    //
    // ------------------------------------------------

    DthWrapper private dthWrapper;
    IProtocolController private protocolController;

    mapping(uint256 => Proposal) private proposals;
    uint256 public proposalsLength;
    mapping(bytes32 => uint256) public proposalHashToId;

    uint64 public constant PCT_BASE = 100e16; // = 100%, 50e16 = 50%, 0 = 0%

    // can be adjusted by manager
    uint64 public supportRequiredPct;
    uint64 public minAcceptQuorumPct;
    uint64 public voteTime;
    uint256 public minProposalStake;

    address public manager;


    // ------------------------------------------------
    //
    // Events
    //
    // ------------------------------------------------

    event SetProtocolController(address protocolController);

    event ChangeManager(address indexed oldManager, address indexed newManager);
    event ChangeSupportRequired(uint64 oldSupportRequiredPct, uint64 newSupportRequiredPct);
    event ChangeMinQuorum(uint64 oldMinAcceptQuorumPct, uint64 newMinAcceptQuorumPct);
    event ChangeMinProposalStake(uint256 oldMinProposalStake, uint256 newMinProposalStake);

    event NewProposal(uint256 indexed proposalId, address indexed creator);
    event PlacedVote(uint256 indexed proposalId, address indexed voter, bool voteYes, uint256 stake);
    event CancelledVote(uint256 indexed proposalId, address indexed voter, bool voteYes, uint256 stake);
    event ExecutedProposal(uint256 indexed proposalId, address indexed executor);

    // ------------------------------------------------
    //
    // Constructor
    //
    // ------------------------------------------------

    constructor(
        address _dthWrapper,
        uint64 _minAcceptQuorumPct,
        uint64 _supportRequiredPct,
        uint256 _minProposalStake,
        uint64 _voteTime
    ) {
        require(_dthWrapper != address(0));
        require(_minAcceptQuorumPct <= _supportRequiredPct, "min accept above support required");
        require(_supportRequiredPct < PCT_BASE, "support required above max");

        dthWrapper = DthWrapper(_dthWrapper);

        supportRequiredPct = _supportRequiredPct;
        minAcceptQuorumPct = _minAcceptQuorumPct;
        minProposalStake = _minProposalStake;
        voteTime = _voteTime;

        manager = msg.sender;
    }

    // ------------------------------------------------
    //
    // Functions Public - manager only
    //
    // ------------------------------------------------

    function setProtocolController(address _protocolController) external {
        require(msg.sender == manager, "only callable by manager");
        require(_protocolController != address(0));
        protocolController = IProtocolController(_protocolController);

        emit SetProtocolController(_protocolController);

        protocolController = IProtocolController(_protocolController);
    }

    function changeManager(address _manager) external {
        require(msg.sender == manager, "only callable by manager");
        require(manager != _manager, "new manager equals current manager");
        require(_manager != address(0), "new manager equals address zero");

        emit ChangeManager(manager, _manager);

        manager = _manager;
    }

    function changeSupportRequiredPct(uint64 _supportRequiredPct) external {
        require(msg.sender == manager, "only callable by manager");
        require(minAcceptQuorumPct <= _supportRequiredPct, "min accept above support required");
        require(_supportRequiredPct < PCT_BASE, "support required above max");

        emit ChangeSupportRequired(supportRequiredPct, _supportRequiredPct);

        supportRequiredPct = _supportRequiredPct;
    }

    function changeMinAcceptQuorumPct(uint64 _minAcceptQuorumPct) external {
        require(msg.sender == manager, "only callable by manager");
        require(minAcceptQuorumPct <= supportRequiredPct, "min accept above support required");

        emit ChangeMinQuorum(minAcceptQuorumPct, _minAcceptQuorumPct);

        minAcceptQuorumPct = _minAcceptQuorumPct;
    }

    function changeMinStakeForProposal(uint256 _minProposalStake) external {
        require(msg.sender == manager, "only callable by manager");
        require(minProposalStake != _minProposalStake, "new min stake equals current min stake");

        emit ChangeMinProposalStake(minProposalStake, _minProposalStake);

        minProposalStake = _minProposalStake;
    }

    // ------------------------------------------------
    //
    // Functions Public - view helpers
    //
    // ------------------------------------------------

    function getProposal(uint256 _proposalId) public view
        returns (
            bool open,
            bool executed,
            uint64 startDate,
            uint64 snapshotBlock,
            uint64 supportRequired,
            uint64 minAcceptQuorum,
            uint256 yea,
            uint256 nay,
            uint256 votingPower,
            ProposalKind kind,
            bytes memory args
        )
    {
        require(_proposalExists(_proposalId), "proposal does not exist");

        Proposal storage proposal = proposals[_proposalId];

        open = _isProposalOpen(proposal);
        executed = proposal.executed;
        startDate = proposal.startDate;
        snapshotBlock = proposal.snapshotBlock;
        supportRequired = proposal.supportRequiredPct;
        minAcceptQuorum = proposal.minAcceptQuorumPct;
        yea = proposal.yea;
        nay = proposal.nay;
        votingPower = proposal.votingPower;
        kind = proposal.kind;
        args = proposal.args;
    }

    function getVoterState(uint256 _proposalId, address _voter) public view returns (VoterState) {
        require(_proposalExists(_proposalId), "proposal does not exist");
        return proposals[_proposalId].voters[_voter];
    }

    // ------------------------------------------------
    //
    // Functions Private - view helpers
    //
    // ------------------------------------------------


    function _proposalExists(uint256 proposalId) private view returns (bool) {
        return proposalId < proposalsLength;
    }

    function _isProposalOpen(Proposal storage _proposal) private view returns (bool) {
        return uint64(block.timestamp) < _proposal.startDate + voteTime && !_proposal.executed;
    }

    function _isActiveProposal(bytes32 _proposalHash) private view returns (bool) {
        return _isProposalOpen(proposals[proposalHashToId[_proposalHash]]);
    }

    function _isValuePct(uint256 _value, uint256 _total, uint256 _pct) private pure returns (bool) {
        if (_total == 0) return false;
        uint256 computedPct = _value * (PCT_BASE) / _total;
        return computedPct > _pct;
    }

    // ------------------------------------------------
    //
    // Functions Private - helpers proposal validation
    //
    // ------------------------------------------------

    function _validateArgsGlobalParams(bytes memory _args) private view {
      require(_args.length == 160, "invalid proposal args length");

      (
        uint256 bidPeriod,
        uint256 cooldownPeriod,
        uint256 entryFee,
        uint256 zoneTax,
        uint256 minRaise
      ) = abi.decode(_args, (uint256, uint256, uint256, uint256, uint256));

      SharedStructs.Params_t memory params = SharedStructs.Params_t(bidPeriod, cooldownPeriod, entryFee, zoneTax, minRaise);

      protocolController.validateGlobalParams(params);
    }

    function _validateArgsSendDth(bytes memory _args) private view {
      require(_args.length == 52, "invalid proposal args length");

      (
        address _recipient,
        uint256 _amount
      ) = abi.decode(_args, (address, uint256));

      protocolController.validateWithdrawDth(_recipient, _amount);
    }

    function _validateArgsCountryFloorPrice(bytes memory _args) private view {
      require(_args.length == 34, "invalid proposal args length");

      (
        bytes2 _countryCode,
        uint256 _floorStakePrice
      ) = abi.decode(_args, (bytes2, uint256));

      protocolController.validateCountryFloorPrice(_countryCode, _floorStakePrice);
    }

    // ------------------------------------------------
    //
    // Functions Public - create Proposal
    //
    // ------------------------------------------------

    function createProposal(
      ProposalKind _proposalKind,
      bytes calldata _proposalArgs
    ) external {
      uint64 snapshotBlock = uint64(block.number) - 1; // avoid double voting in this very block
      uint256 voterStake = dthWrapper.balanceOfAt(msg.sender, snapshotBlock);
      require(voterStake >= minProposalStake, "not enough wrapped dth");

      bytes32 proposalHash = keccak256(_proposalArgs);
      require(!_isActiveProposal(proposalHash), "proposal with same args already exists");

      if (_proposalKind == ProposalKind.GlobalParams) {
        _validateArgsGlobalParams(_proposalArgs);
      } else if (_proposalKind == ProposalKind.CountryFloorPrice) {
        _validateArgsCountryFloorPrice(_proposalArgs);
      } else if (_proposalKind == ProposalKind.SendDth) {
        _validateArgsSendDth(_proposalArgs);
      }

      uint256 proposalId = proposalsLength++;

      Proposal storage proposal = proposals[proposalId];
      proposal.startDate = uint64(block.timestamp);
      proposal.snapshotBlock = snapshotBlock;
      proposal.supportRequiredPct = supportRequiredPct;
      proposal.minAcceptQuorumPct = minAcceptQuorumPct;
      proposal.votingPower = dthWrapper.totalSupplyAt(snapshotBlock);
      proposal.kind = _proposalKind;
      proposal.args = _proposalArgs;

      proposalHashToId[proposalHash] = proposalId;

      emit NewProposal(proposalId, msg.sender);
    }

    // ------------------------------------------------
    //
    // Functions Public - voting
    //
    // ------------------------------------------------

    function placeVote(uint256 _proposalId, bool _voteYes) external {
        Proposal storage proposal = proposals[_proposalId];
        require(_isProposalOpen(proposal), "proposal cannot be voted on");

        uint256 voterStake = dthWrapper.balanceOfAt(msg.sender, proposal.snapshotBlock);
        require(voterStake > 0, "caller does not have voting tokens");

        VoterState state = proposal.voters[msg.sender];
        require(state == VoterState.Absent ||
                state == VoterState.Yea && !_voteYes ||
                state == VoterState.Nay && _voteYes, "already voted that side");

        if (state == VoterState.Yea) {
            proposal.yea -= voterStake;
        } else if (state == VoterState.Nay) {
            proposal.nay -= voterStake;
        }

        if (_voteYes) {
            proposal.yea += voterStake;
        } else {
            proposal.nay += voterStake;
        }

        proposal.voters[msg.sender] = _voteYes ? VoterState.Yea : VoterState.Nay;

        emit PlacedVote(_proposalId, msg.sender, _voteYes, voterStake);
    }

    function cancelVote(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(_isProposalOpen(proposal), "proposal cannot be voted on");

        uint256 voterStake = dthWrapper.balanceOfAt(msg.sender, proposal.snapshotBlock);
        require(voterStake > 0, "caller does not have voting tokens");

        VoterState state = proposal.voters[msg.sender];
        require(state == VoterState.Yea || state == VoterState.Nay, "did not place a vote");

        if (state == VoterState.Yea) {
            proposal.yea -= voterStake;
        } else if (state == VoterState.Nay) {
            proposal.nay -= voterStake;
        }

        proposal.voters[msg.sender] = VoterState.Absent;

        emit CancelledVote(_proposalId, msg.sender, state == VoterState.Yea ? true : false, voterStake);
    }

    function execute(uint256 _proposalId) external {
        require(_proposalId < proposalsLength, "proposal does not exist");

        Proposal storage proposal = proposals[_proposalId];

        require(!_isProposalOpen(proposal), "proposal is not open");
        require(_isValuePct(proposal.yea, proposal.votingPower, proposal.supportRequiredPct), "not enough support of votingPower");
        require(_isValuePct(proposal.yea, proposal.yea + proposal.nay, proposal.supportRequiredPct), "not enough support of placed votes");
        require(_isValuePct(proposal.yea, proposal.votingPower, proposal.minAcceptQuorumPct), "did not reach quorum of votingPower");

        proposal.executed = true;

        if (proposal.kind == ProposalKind.GlobalParams) {
          (
            uint256 _bidPeriod,
            uint256 _cooldownPeriod,
            uint256 _entryFee,
            uint256 _zoneTax,
            uint256 _minRaise
          ) = abi.decode(proposal.args, (uint256, uint256, uint256, uint256, uint256));

          SharedStructs.Params_t memory params = SharedStructs.Params_t(_bidPeriod, _cooldownPeriod, _entryFee, _zoneTax, _minRaise);

          protocolController.updateGlobalParams(params);
        }

        else if (proposal.kind == ProposalKind.CountryFloorPrice) {
          (
            bytes2 _countryCode,
            uint256 _floorPrice
          ) = abi.decode(proposal.args, (bytes2, uint256));

          protocolController.updateCountryFloorPrice(_countryCode, _floorPrice);
        }

        else if (proposal.kind == ProposalKind.SendDth) {
          (
            address _recipient,
            uint256 _amount
          ) = abi.decode(proposal.args, (address, uint256));

          protocolController.withdrawDth(_recipient, _amount, ""); // TODO: 3th arg: id?
        }

        emit ExecutedProposal(_proposalId, msg.sender);
    }
}

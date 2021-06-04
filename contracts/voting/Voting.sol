pragma solidity ^0.8.1;
pragma experimental ABIEncoderV2;

import "./DthWrapper.sol";
import "../interfaces/IProtocolController.sol";

contract Voting {
    // ------------------------------------------------
    //
    // Enums
    //
    // ------------------------------------------------

    enum VoterState {Absent, Yea, Nay}
    enum ProposalKind {GlobalParams, CountryFloorPrice, SendDth}
    enum ProposalExecutionState {NotYetExecuted, Succeeded, Failed}

    // ------------------------------------------------
    //
    // Structs
    //
    // ------------------------------------------------

    struct Proposal {
        uint64 startDate;
        uint64 snapshotBlock;
        uint64 supportRequiredPct;
        uint64 minAcceptQuorumPct;
        address creator;
        ProposalExecutionState state;
        ProposalKind kind;
        uint256 yea;
        uint256 nay;
        uint256 votingPower;
        bytes args;
        bytes32 argsHash;
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
    uint256 public proposalIdCounter;
    mapping(bytes32 => uint256) public proposalHashToId;
    mapping(address => uint256) public userToProposalId;
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
    event ChangeSupportRequired(
        uint64 oldSupportRequiredPct,
        uint64 newSupportRequiredPct
    );
    event ChangeMinQuorum(
        uint64 oldMinAcceptQuorumPct,
        uint64 newMinAcceptQuorumPct
    );
    event ChangeMinProposalStake(
        uint256 oldMinProposalStake,
        uint256 newMinProposalStake
    );

    event NewProposal(uint256 indexed proposalId, address indexed creator);
    event PlacedVote(
        uint256 indexed proposalId,
        address indexed voter,
        bool voteYes,
        uint256 stake
    );
    event ExecutedProposal(
        uint256 indexed proposalId,
        address indexed executor
    );
    event ProposalFailed(uint256 indexed proposalId);

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
        require(
            _minAcceptQuorumPct <= _supportRequiredPct,
            "min accept above support required"
        );
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
        require(
            minAcceptQuorumPct <= _supportRequiredPct,
            "min accept above support required"
        );
        require(_supportRequiredPct < PCT_BASE, "support required above max");

        emit ChangeSupportRequired(supportRequiredPct, _supportRequiredPct);

        supportRequiredPct = _supportRequiredPct;
    }

    function changeMinAcceptQuorumPct(uint64 _minAcceptQuorumPct) external {
        require(msg.sender == manager, "only callable by manager");
        require(
            minAcceptQuorumPct <= supportRequiredPct,
            "min accept above support required"
        );

        emit ChangeMinQuorum(minAcceptQuorumPct, _minAcceptQuorumPct);

        minAcceptQuorumPct = _minAcceptQuorumPct;
    }

    function changeMinStakeForProposal(uint256 _minProposalStake) external {
        require(msg.sender == manager, "only callable by manager");
        require(
            minProposalStake != _minProposalStake,
            "new min stake equals current min stake"
        );

        emit ChangeMinProposalStake(minProposalStake, _minProposalStake);

        minProposalStake = _minProposalStake;
    }

    // ------------------------------------------------
    //
    // Functions Public - view helpers
    //
    // ------------------------------------------------

    function getProposal(uint256 _proposalId)
        public
        view
        returns (
            bool open,
            ProposalExecutionState state,
            uint64 startDate,
            uint64 snapshotBlock,
            uint64 supportRequired,
            uint64 minAcceptQuorum,
            uint256 yea,
            uint256 nay,
            uint256 votingPower,
            ProposalKind kind,
            bytes memory args,
            address creator
        )
    // bytes32 argsHash
    {
        require(_proposalIdExists(_proposalId), "proposal does not exist");

        Proposal storage proposal = proposals[_proposalId];

        open = !_proposalEnded(proposal);
        state = proposal.state;
        startDate = proposal.startDate;
        snapshotBlock = proposal.snapshotBlock;
        supportRequired = proposal.supportRequiredPct;
        minAcceptQuorum = proposal.minAcceptQuorumPct;
        yea = proposal.yea;
        nay = proposal.nay;
        votingPower = proposal.votingPower;
        kind = proposal.kind;
        args = proposal.args;
        creator = proposal.creator;
    }

    function getVoterState(uint256 _proposalId, address _voter)
        public
        view
        returns (VoterState)
    {
        require(_proposalIdExists(_proposalId), "proposal does not exist");
        return proposals[_proposalId].voters[_voter];
    }

    // ------------------------------------------------
    //
    // Functions Private - view helpers
    //
    // ------------------------------------------------

    function _proposalIdExists(uint256 proposalId) private view returns (bool) {
        return proposalId > 0 && proposalId <= proposalIdCounter;
    }

    function _proposalEnded(Proposal storage _proposal)
        private
        view
        returns (bool)
    {
        return uint64(block.timestamp) >= _proposal.startDate + voteTime;
    }

    function _isValuePct(
        uint256 _value,
        uint256 _total,
        uint256 _pct
    ) private pure returns (bool) {
        if (_total == 0) return false;
        uint256 computedPct = (_value * (PCT_BASE)) / _total;
        return computedPct > _pct;
    }

    // ------------------------------------------------
    //
    // Functions Private - helpers proposal validation
    //
    // ------------------------------------------------

    function _validateArgsGlobalParams(uint256 _proposalId, bytes memory _args)
        private
        returns (bytes32)
    {
        require(_args.length == 160, "invalid proposal args length");

        (
            uint256 bidPeriod,
            uint256 cooldownPeriod,
            uint256 entryFee,
            uint256 zoneTax,
            uint256 minRaise
        ) = abi.decode(_args, (uint256, uint256, uint256, uint256, uint256));

        bytes32 proposalHash =
            keccak256(
                abi.encodePacked(
                    bidPeriod,
                    cooldownPeriod,
                    entryFee,
                    zoneTax,
                    minRaise
                )
            );
        require(
            proposalHashToId[proposalHash] == 0,
            "proposal with same args already exists"
        );
        proposalHashToId[proposalHash] = _proposalId;

        IProtocolController.GlobalParams memory params =
            IProtocolController.GlobalParams(
                bidPeriod,
                cooldownPeriod,
                entryFee,
                zoneTax,
                minRaise
            );

        protocolController.validateGlobalParams(params);

        return proposalHash;
    }

    function _validateArgsSendDth(uint256 _proposalId, bytes memory _args)
        private
        returns (bytes32)
    {
        require(_args.length == 64, "invalid proposal args length");

        (address recipient, uint256 amount) =
            abi.decode(_args, (address, uint256));

        bytes32 proposalHash = keccak256(abi.encodePacked(recipient, amount));
        require(
            proposalHashToId[proposalHash] == 0,
            "proposal with same args already exists"
        );
        proposalHashToId[proposalHash] = _proposalId;

        protocolController.validateWithdrawDth(recipient, amount);

        return proposalHash;
    }

    function _validateArgsCountryFloorPrice(
        uint256 _proposalId,
        bytes memory _args
    ) private returns (bytes32) {
        require(_args.length == 64, "invalid proposal args length");

        (bytes2 countryCode, uint256 floorStakePrice) =
            abi.decode(_args, (bytes2, uint256));

        bytes32 proposalHash =
            keccak256(abi.encodePacked(countryCode, floorStakePrice));
        require(
            proposalHashToId[proposalHash] == 0,
            "proposal with same args already exists"
        );
        proposalHashToId[proposalHash] = _proposalId;

        protocolController.validateCountryFloorPrice(
            countryCode,
            floorStakePrice
        );

        return proposalHash;
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
        require(
            address(protocolController) != address(0),
            "protocolController not set"
        );

        uint64 snapshotBlock = uint64(block.number) - 1;
        uint256 voterStake = dthWrapper.balanceOfAt(msg.sender, snapshotBlock);
        require(voterStake >= minProposalStake, "not enough wrapped dth");

        require(userToProposalId[msg.sender] == 0, "user already has proposal");

        uint256 proposalId = ++proposalIdCounter;

        bytes32 proposalHash;
        if (_proposalKind == ProposalKind.GlobalParams) {
            proposalHash = _validateArgsGlobalParams(proposalId, _proposalArgs);
        } else if (_proposalKind == ProposalKind.CountryFloorPrice) {
            proposalHash = _validateArgsCountryFloorPrice(
                proposalId,
                _proposalArgs
            );
        } else if (_proposalKind == ProposalKind.SendDth) {
            proposalHash = _validateArgsSendDth(proposalId, _proposalArgs);
        }

        userToProposalId[msg.sender] = proposalId;

        Proposal storage proposal = proposals[proposalId];
        // proposal.state will default to enum value 0, which stands for "Active"
        proposal.startDate = uint64(block.timestamp);
        proposal.snapshotBlock = snapshotBlock;
        proposal.supportRequiredPct = supportRequiredPct;
        proposal.minAcceptQuorumPct = minAcceptQuorumPct;
        proposal.votingPower = dthWrapper.totalSupplyAt(snapshotBlock);
        proposal.kind = _proposalKind;
        proposal.args = _proposalArgs;
        proposal.argsHash = proposalHash;
        proposal.creator = msg.sender;

        emit NewProposal(proposalId, msg.sender);
    }

    // ------------------------------------------------
    //
    // Functions Public - voting
    //
    // ------------------------------------------------

    function placeVote(uint256 _proposalId, bool _voteYes) external {
        require(_proposalIdExists(_proposalId), "proposal does not exist");

        Proposal storage proposal = proposals[_proposalId];
        require(!_proposalEnded(proposal), "proposal ended");

        uint256 voterStake =
            dthWrapper.balanceOfAt(msg.sender, proposal.snapshotBlock);
        require(voterStake > 0, "caller does not have voting tokens");

        VoterState state = proposal.voters[msg.sender];
        require(
            state == VoterState.Absent ||
                (state == VoterState.Yea && !_voteYes) ||
                (state == VoterState.Nay && _voteYes),
            "already voted that side"
        );

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

        proposal.voters[msg.sender] = _voteYes
            ? VoterState.Yea
            : VoterState.Nay;

        emit PlacedVote(_proposalId, msg.sender, _voteYes, voterStake);
    }

    function execute(uint256 _proposalId) external {
        require(_proposalIdExists(_proposalId), "proposal does not exist");

        Proposal storage proposal = proposals[_proposalId];

        require(_proposalEnded(proposal), "proposal did not yet end");
        require(
            proposal.state == ProposalExecutionState.NotYetExecuted,
            "proposal already executed"
        );
        userToProposalId[proposal.creator] = 0;
        proposalHashToId[proposal.argsHash] = 0;

        bool successCasted =
            _isValuePct(
                proposal.yea,
                proposal.yea + proposal.nay,
                proposal.supportRequiredPct
            );
        bool successAll =
            _isValuePct(
                proposal.yea,
                proposal.votingPower,
                proposal.minAcceptQuorumPct
            );

        if (!successCasted || !successAll) {
            proposal.state = ProposalExecutionState.Failed;
            emit ProposalFailed(_proposalId);
            return;
        }

        proposal.state = ProposalExecutionState.Succeeded;

        if (proposal.kind == ProposalKind.GlobalParams) {
            (
                uint256 _bidPeriod,
                uint256 _cooldownPeriod,
                uint256 _entryFee,
                uint256 _zoneTax,
                uint256 _minRaise
            ) =
                abi.decode(
                    proposal.args,
                    (uint256, uint256, uint256, uint256, uint256)
                );

            IProtocolController.GlobalParams memory params =
                IProtocolController.GlobalParams(
                    _bidPeriod,
                    _cooldownPeriod,
                    _entryFee,
                    _zoneTax,
                    _minRaise
                );

            protocolController.updateGlobalParams(params);
        } else if (proposal.kind == ProposalKind.CountryFloorPrice) {
            (bytes2 _countryCode, uint256 _floorPrice) =
                abi.decode(proposal.args, (bytes2, uint256));

            protocolController.updateCountryFloorPrice(
                _countryCode,
                _floorPrice
            );
        } else if (proposal.kind == ProposalKind.SendDth) {
            (address _recipient, uint256 _amount) =
                abi.decode(proposal.args, (address, uint256));

            protocolController.withdrawDth(_recipient, _amount, ""); // TODO: 3th arg: id?
        }

        emit ExecutedProposal(_proposalId, msg.sender);
    }
}

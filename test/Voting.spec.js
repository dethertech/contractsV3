/* eslint-env mocha */
/* global artifacts, contract */
/* eslint-disable max-len, no-multi-spaces, no-unused-expressions */

const DetherToken = artifacts.require("DetherToken");
const Users = artifacts.require("Users");
const CertifierRegistry = artifacts.require("CertifierRegistry");
const GeoRegistry = artifacts.require("GeoRegistry");
const ZoneFactory = artifacts.require("ZoneFactory");
const Zone = artifacts.require("Zone");
const Teller = artifacts.require("Teller");
// const TaxCollector = artifacts.require("TaxCollector");
const ProtocolController = artifacts.require("ProtocolController");
const DthWrapper = artifacts.require("DthWrapper");
const Voting = artifacts.require("Voting");

const Web3 = require("web3");

const expect = require("./utils/chai");
const TimeTravel = require("./utils/timeTravel");
const { addCountry } = require("./utils/geo");
const { ethToWei, asciiToHex, str, weiToEth, toVotingPerc } = require("./utils/convert");
const { expectRevert2 } = require("./utils/evmErrors");

const web3 = new Web3("http://localhost:8545");
const timeTravel = new TimeTravel(web3);

const getBlockTimestamp = async (nr) =>
  (await web3.eth.getBlock(nr)).timestamp;

const PROPOSAL_KIND = {
  GlobalParams: 0,
  CountryFloorPrice: 1,
  SendDth: 2
}

const encodeProposalArgs = (kind, args) => {
  switch (kind) {
    case PROPOSAL_KIND.GlobalParams:
      return web3.eth.abi.encodeParameters(
        ["uint256", "uint256", "uint256", "uint256", "uint256"],
        [args[0], args[1], args[2], args[3], args[4]]
      );
    case PROPOSAL_KIND.CountryFloorPrice:
      return web3.eth.abi.encodeParameters(
        ["bytes2", "uint256"],
        [args[0], args[1]]
      );
    case PROPOSAL_KIND.SendDth:
      return web3.eth.abi.encodeParameters(
        ["address", "uint256"],
        [args[0], args[1]]
      );
  }
};

contract("ProtocolController + Voting + DthWrapper", (accounts) => {
  let owner;
  let user1;
  let user2;
  let user3;
  let user4;
  let user5;
  let user6; // does not have any Dth, used as SendDth recipient


  let __rootState__; // eslint-disable-line no-underscore-dangle

  let dthInstance;
  let usersInstance;
  let geoInstance;
  let zoneFactoryInstance;
  let zoneImplementationInstance;
  let tellerImplementationInstance;
  let certifierRegistryInstance;
  let protocolControllerInstance;
  let votingInstance;
  let dthWrapperInstance;

  before(async () => {
    __rootState__ = await timeTravel.saveState();
    [owner, user1, user2, user3, user4, user5, user6] = accounts;
  });

  beforeEach(async () => {
    await timeTravel.revertState(__rootState__); // to go back to real time

    dthInstance = await DetherToken.new({ from: owner });

    certifierRegistryInstance = await CertifierRegistry.new({ from: owner });

    geoInstance = await GeoRegistry.new({ from: owner });

    zoneImplementationInstance = await Zone.new({
      from: owner,
    });

    tellerImplementationInstance = await Teller.new({ from: owner });

    usersInstance = await Users.new(
      geoInstance.address,
      certifierRegistryInstance.address,
      { from: owner }
    );

    //
    //
    // NEW STUFF
    //
    //

    dthWrapperInstance = await DthWrapper.new(dthInstance.address, { from: owner });
    votingInstance = await Voting.new(
      dthWrapperInstance.address,
      toVotingPerc(25), // % of possible votes
      toVotingPerc(60), // % of casted votes
      ethToWei(1),     // 1 DTH
      7*24*60*60,       // 7 days
      { from: owner }
    );
    protocolControllerInstance = await ProtocolController.new(dthInstance.address, votingInstance.address, geoInstance.address, { from: owner });
    await votingInstance.setProtocolController(protocolControllerInstance.address, { from: owner });

    zoneFactoryInstance = await ZoneFactory.new(
      dthInstance.address,
      geoInstance.address,
      usersInstance.address,
      zoneImplementationInstance.address,
      tellerImplementationInstance.address,
      protocolControllerInstance.address,
      { from: owner }
    );

    await addCountry(owner, web3, geoInstance, 'CG', 300);

    await dthInstance.mint(user1, ethToWei(100), { from: owner });
    await dthInstance.mint(user2, ethToWei(100), { from: owner });
    await dthInstance.mint(user3, ethToWei(100), { from: owner });
    await dthInstance.mint(user4, ethToWei(100), { from: owner });
    await dthInstance.mint(user5, ethToWei(100), { from: owner });
  });

  const wrapDth = async (from, amount) => {
    await web3.eth.sendTransaction({
      from,
      to: dthInstance.address,
      data: [
        web3.eth.abi.encodeFunctionSignature(
          "transfer(address,uint256,bytes)"
        ),
        web3.eth.abi.encodeParameters(
          ["address", "uint256", "bytes"],
          [dthWrapperInstance.address, ethToWei(amount), `0x`]
        ).slice(2)
      ].join(""),
      value: 0,
      gas: 4700000,
    })
    expect((await dthWrapperInstance.balanceOf(from)).toString()).to.equal(ethToWei(amount));
  }

  describe('Voting', () => {
    describe('ProposalKind.GlobalParams', () => {
      describe('createProposal()', () => {
        it("cannot create proposal if no wrapped dth", async () => {
          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
              { from: user1 }
            ),
            'not enough wrapped dth'
          )
        });

        it("cannot create proposal if less than minimum wrapped dth", async () => {
          await wrapDth(user1, 0.9);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
              { from: user1 }
            ),
            'not enough wrapped dth'
          )
        });

        it("success", async () => {
          await wrapDth(user1, 1);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.startDate.toString()).to.equal(blockTimestamp.toString());
          expect(proposal.snapshotBlock.toString()).to.equal((blockNr-1).toString());
          expect(proposal.minAcceptQuorum.toString()).to.equal(toVotingPerc(25).toString());
          expect(proposal.supportRequired.toString()).to.equal(toVotingPerc(60).toString());
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal('0');
          expect(proposal.votingPower.toString()).to.equal(ethToWei(1));
          expect(proposal.kind.toString()).to.equal('0');
        });

        it("cannot create proposal with identical args as existing active proposal", async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
              { from: user2 }
            ),
            'proposal with same args already exists'
          )
        });

        it("cannot create proposal if user already has active proposal", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
              { from: user1 }
            ),
            'user already has proposal'
          )
        });

        it("cannot create new proposal if old proposal ended but not yet executed", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
              { from: user1 }
            ),
            'user already has proposal'
          )
        });

        it("can create new proposal if old proposal ended and was executed", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7*24*60*60);

          await votingInstance.execute(1, { from: user1 });

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
            { from: user1 }
          );
        });
      });

      describe('placeVote()', () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.startDate.toString()).to.equal(blockTimestamp.toString());
          expect(proposal.snapshotBlock.toString()).to.equal((blockNr-1).toString());
          expect(proposal.minAcceptQuorum.toString()).to.equal(toVotingPerc(25).toString());
          expect(proposal.supportRequired.toString()).to.equal(toVotingPerc(60).toString());
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal('0');
          expect(proposal.votingPower.toString()).to.equal(ethToWei(2));
          expect(proposal.kind.toString()).to.equal('0');
        });

        it("cannot vote on nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.placeVote(99, true, { from: user2 }),
            'proposal does not exist'
          )
        });

        it("cannot vote on proposal that ended", async () => {
          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            'proposal ended'
          )
        });

        it("cannot vote without wrapped dth", async () => {
          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user3 }),
            'caller does not have voting tokens'
          )
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.yea.toString()).to.equal(ethToWei(1));
          expect(proposal.nay.toString()).to.equal('0');
        });

        it("cannot vote the same side again", async () => {
          await votingInstance.placeVote(1, true, { from: user2 }),

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            'already voted that side'
          )
        });

        it("can change existing vote's side", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          await votingInstance.placeVote(1, false, { from: user2 });
          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal(ethToWei(1));
        });
      });

      describe('execute()', () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);
          await wrapDth(user3, 2);
          await wrapDth(user4, 2);
          await wrapDth(user5, 4);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [2*60*60, 1*60*60, 10, 100, 40]),
            { from: user1 }
          );
        });

        it("cannot execute nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.execute(99, { from: user2 }),
            'proposal does not exist'
          )
        });

        it("cannot execute proposal that did not yet end", async () => {
          await expectRevert2(
            votingInstance.execute(1, { from: user2 }),
            'proposal did not yet end'
          )
        });

        it("cannot execute proposal with not enough % of casted votes", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, false, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 50% yea, 50% nay

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'not enough support in casted votes'
          )
        });

        it("cannot execute proposal with that did not enough % of possible votes", async () => {
          await votingInstance.placeVote(1, false, { from: user1 });
          await votingInstance.placeVote(1, true, { from: user3 });
          // casted votes = 66% yea, 33% nay
          // possible votes = 20% yea

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'not enough support in possible votes'
          )
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7*24*60*60);

          let proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.executed).to.equal(false);

          const oldGlobalParams = await protocolControllerInstance.globalParams();
          expect(oldGlobalParams.bidPeriod.toString()).to.equal((48*60*60).toString());
          expect(oldGlobalParams.cooldownPeriod.toString()).to.equal((24*60*60).toString());
          expect(oldGlobalParams.entryFee.toString()).to.equal((4).toString());
          expect(oldGlobalParams.zoneTax.toString()).to.equal((4).toString());
          expect(oldGlobalParams.minRaise.toString()).to.equal((6).toString());

          await votingInstance.execute(1, { from: user3 });

          proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.executed).to.equal(true);
          expect(proposal.yea.toString()).to.equal(ethToWei(7));
          expect(proposal.nay.toString()).to.equal(ethToWei(3));
          expect(proposal.votingPower.toString()).to.equal(ethToWei(10));

          const newGlobalParams = await protocolControllerInstance.globalParams();
          expect(newGlobalParams.bidPeriod.toString()).to.equal((2*60*60).toString());
          expect(newGlobalParams.cooldownPeriod.toString()).to.equal((1*60*60).toString());
          expect(newGlobalParams.entryFee.toString()).to.equal((10).toString());
          expect(newGlobalParams.zoneTax.toString()).to.equal((100).toString());
          expect(newGlobalParams.minRaise.toString()).to.equal((40).toString());
        });

        it("cannot execute proposal that was already executed", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7*24*60*60);

          await votingInstance.execute(1, { from: user3 });

          // try to execute again

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'proposal already executed'
          )
        });
      });
    });
    describe('ProposalKind.CountryFloorPrice', () => {
      describe('createProposal()', () => {
        it("cannot create proposal if no wrapped dth", async () => {
          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
              { from: user1 }
            ),
            'not enough wrapped dth'
          )
        });

        it("cannot create proposal if less than minimum wrapped dth", async () => {
          await wrapDth(user1, 0.9);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
              { from: user1 }
            ),
            'not enough wrapped dth'
          )
        });

        it("success", async () => {
          await wrapDth(user1, 1);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.startDate.toString()).to.equal(blockTimestamp.toString());
          expect(proposal.snapshotBlock.toString()).to.equal((blockNr-1).toString());
          expect(proposal.minAcceptQuorum.toString()).to.equal(toVotingPerc(25).toString());
          expect(proposal.supportRequired.toString()).to.equal(toVotingPerc(60).toString());
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal('0');
          expect(proposal.votingPower.toString()).to.equal(ethToWei(1));
          expect(proposal.kind.toString()).to.equal('1');
        });

        it("cannot create proposal with identical args as existing active proposal", async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
              { from: user2 }
            ),
            'proposal with same args already exists'
          )
        });

        it("cannot create proposal if user already has active proposal", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
              { from: user1 }
            ),
            'user already has proposal'
          )
        });

        it("cannot create new proposal if old proposal ended but not yet executed", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
              { from: user1 }
            ),
            'user already has proposal'
          )
        });

        it("can create new proposal if old proposal ended and was executed", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7*24*60*60);

          await votingInstance.execute(1, { from: user1 });

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
            { from: user1 }
          );
        });
      });

      describe('placeVote()', () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.startDate.toString()).to.equal(blockTimestamp.toString());
          expect(proposal.snapshotBlock.toString()).to.equal((blockNr-1).toString());
          expect(proposal.minAcceptQuorum.toString()).to.equal(toVotingPerc(25).toString());
          expect(proposal.supportRequired.toString()).to.equal(toVotingPerc(60).toString());
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal('0');
          expect(proposal.votingPower.toString()).to.equal(ethToWei(2));
          expect(proposal.kind.toString()).to.equal('1');
        });

        it("cannot vote on nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.placeVote(99, true, { from: user2 }),
            'proposal does not exist'
          )
        });

        it("cannot vote on proposal that ended", async () => {
          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            'proposal ended'
          )
        });

        it("cannot vote without wrapped dth", async () => {
          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user3 }),
            'caller does not have voting tokens'
          )
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.yea.toString()).to.equal(ethToWei(1));
          expect(proposal.nay.toString()).to.equal('0');
        });

        it("cannot vote the same side again", async () => {
          await votingInstance.placeVote(1, true, { from: user2 }),

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            'already voted that side'
          )
        });

        it("can change existing vote's side", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          await votingInstance.placeVote(1, false, { from: user2 });
          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal(ethToWei(1));
        });
      });

      describe('execute()', () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);
          await wrapDth(user3, 2);
          await wrapDth(user4, 2);
          await wrapDth(user5, 4);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [asciiToHex('CG'), ethToWei(7)]),
            { from: user1 }
          );
        });

        it("cannot execute nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.execute(99, { from: user2 }),
            'proposal does not exist'
          )
        });

        it("cannot execute proposal that did not yet end", async () => {
          await expectRevert2(
            votingInstance.execute(1, { from: user2 }),
            'proposal did not yet end'
          )
        });

        it("cannot execute proposal with not enough % of casted votes", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, false, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 50% yea, 50% nay

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'not enough support'
          )
        });

        it("cannot execute proposal with that did not enough % of possible votes", async () => {
          await votingInstance.placeVote(1, false, { from: user1 });
          await votingInstance.placeVote(1, true, { from: user3 });
          // casted votes = 66% yea, 33% nay
          // possible votes = 20% yea

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'not enough support in possible votes'
          )
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7*24*60*60);

          let proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.executed).to.equal(false);

          const oldCountryFloorPrice = await protocolControllerInstance.floorStakesPrices(asciiToHex('CG'));
          expect(oldCountryFloorPrice.toString()).to.equal(ethToWei(0));

          await votingInstance.execute(1, { from: user3 });

          proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.executed).to.equal(true);
          expect(proposal.yea.toString()).to.equal(ethToWei(7));
          expect(proposal.nay.toString()).to.equal(ethToWei(3));
          expect(proposal.votingPower.toString()).to.equal(ethToWei(10));

          const newCountryFloorPrice = await protocolControllerInstance.floorStakesPrices(asciiToHex('CG'));
          expect(newCountryFloorPrice.toString()).to.equal(ethToWei(7));
        });

        it("cannot execute proposal that was already executed", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7*24*60*60);

          await votingInstance.execute(1, { from: user3 });

          // try to execute again

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'proposal already executed'
          )
        });
      });
    });
    describe('ProposalKind.SendDth', () => {
      const payTaxesToProtocolController = async (from, amount) => {
        await web3.eth.sendTransaction({
          from,
          to: dthInstance.address,
          data: [
            web3.eth.abi.encodeFunctionSignature(
              "transfer(address,uint256,bytes)"
            ),
            web3.eth.abi.encodeParameters(
              ["address", "uint256", "bytes"],
              [protocolControllerInstance.address, ethToWei(amount), `0x`]
            ).slice(2)
          ].join(""),
          value: 0,
          gas: 4700000,
        })
        expect((await dthInstance.balanceOf(protocolControllerInstance.address)).toString()).to.equal(ethToWei(amount));
      }
      describe('createProposal()', () => {
        it("cannot create proposal if no wrapped dth", async () => {
          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.SendDth,
              encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
              { from: user1 }
            ),
            'not enough wrapped dth'
          )
        });

        it("cannot create proposal if less than minimum wrapped dth", async () => {
          await wrapDth(user1, 0.9);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.SendDth,
              encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
              { from: user1 }
            ),
            'not enough wrapped dth'
          )
        });

        it("success", async () => {
          await wrapDth(user1, 1);

          await payTaxesToProtocolController(user1, 7);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.startDate.toString()).to.equal(blockTimestamp.toString());
          expect(proposal.snapshotBlock.toString()).to.equal((blockNr-1).toString());
          expect(proposal.minAcceptQuorum.toString()).to.equal(toVotingPerc(25).toString());
          expect(proposal.supportRequired.toString()).to.equal(toVotingPerc(60).toString());
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal('0');
          expect(proposal.votingPower.toString()).to.equal(ethToWei(1));
          expect(proposal.kind.toString()).to.equal('2');
        });

        it("cannot create proposal with identical args as existing active proposal", async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          await payTaxesToProtocolController(user1, 7);

          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.SendDth,
              encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
              { from: user2 }
            ),
            'proposal with same args already exists'
          )
        });

        it("cannot create proposal if user already has active proposal", async () => {
          await wrapDth(user1, 1);

          await payTaxesToProtocolController(user1, 7);

          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.SendDth,
              encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
              { from: user1 }
            ),
            'user already has proposal'
          )
        });

        it("cannot create new proposal if old proposal ended but not yet executed", async () => {
          await wrapDth(user1, 1);

          await payTaxesToProtocolController(user1, 7);

          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.SendDth,
              encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
              { from: user1 }
            ),
            'user already has proposal'
          )
        });

        it("can create new proposal if old proposal ended and was executed", async () => {
          await wrapDth(user1, 1);

          await payTaxesToProtocolController(user1, 7);

          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7*24*60*60);

          await votingInstance.execute(1, { from: user1 });

          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(1)]),
            { from: user1 }
          );
        });
      });

      describe('placeVote()', () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          await payTaxesToProtocolController(user1, 7);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.startDate.toString()).to.equal(blockTimestamp.toString());
          expect(proposal.snapshotBlock.toString()).to.equal((blockNr-1).toString());
          expect(proposal.minAcceptQuorum.toString()).to.equal(toVotingPerc(25).toString());
          expect(proposal.supportRequired.toString()).to.equal(toVotingPerc(60).toString());
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal('0');
          expect(proposal.votingPower.toString()).to.equal(ethToWei(2));
          expect(proposal.kind.toString()).to.equal('2');
        });

        it("cannot vote on nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.placeVote(99, true, { from: user2 }),
            'proposal does not exist'
          )
        });

        it("cannot vote on proposal that ended", async () => {
          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            'proposal ended'
          )
        });

        it("cannot vote without wrapped dth", async () => {
          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user3 }),
            'caller does not have voting tokens'
          )
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.yea.toString()).to.equal(ethToWei(1));
          expect(proposal.nay.toString()).to.equal('0');
        });

        it("cannot vote the same side again", async () => {
          await votingInstance.placeVote(1, true, { from: user2 }),

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            'already voted that side'
          )
        });

        it("can change existing vote's side", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          await votingInstance.placeVote(1, false, { from: user2 });
          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.executed).to.equal(false);
          expect(proposal.yea.toString()).to.equal('0');
          expect(proposal.nay.toString()).to.equal(ethToWei(1));
        });
      });

      describe('execute()', () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);
          await wrapDth(user3, 2);
          await wrapDth(user4, 2);
          await wrapDth(user5, 4);

          await payTaxesToProtocolController(user1, 7);

          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
            { from: user1 }
          );
        });

        it("cannot execute nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.execute(99, { from: user2 }),
            'proposal does not exist'
          )
        });

        it("cannot execute proposal that did not yet end", async () => {
          await expectRevert2(
            votingInstance.execute(1, { from: user2 }),
            'proposal did not yet end'
          )
        });

        it("cannot execute proposal with not enough % of casted votes", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, false, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 50% yea, 50% nay

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'not enough support in casted votes'
          )
        });

        it("cannot execute proposal with that did not enough % of possible votes", async () => {
          await votingInstance.placeVote(1, false, { from: user1 });
          await votingInstance.placeVote(1, true, { from: user3 });
          // casted votes = 66% yea, 33% nay
          // possible votes = 20% yea

          await timeTravel.inSecs(7*24*60*60);

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'not enough support in possible votes'
          )
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7*24*60*60);

          let proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.executed).to.equal(false);

          const oldProtocolControllerBalanceDth = (await dthInstance.balanceOf(protocolControllerInstance.address)).toString();
          const oldUser6BalanceDth = (await dthInstance.balanceOf(user6)).toString();
          expect(oldProtocolControllerBalanceDth.toString()).to.equal(ethToWei(7));
          expect(oldUser6BalanceDth.toString()).to.equal(ethToWei(0));

          await votingInstance.execute(1, { from: user3 });

          proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.executed).to.equal(true);
          expect(proposal.yea.toString()).to.equal(ethToWei(7));
          expect(proposal.nay.toString()).to.equal(ethToWei(3));
          expect(proposal.votingPower.toString()).to.equal(ethToWei(10));

          const newProtocolControllerBalanceDth = (await dthInstance.balanceOf(protocolControllerInstance.address)).toString();
          const newUser6BalanceDth = (await dthInstance.balanceOf(user6)).toString();
          expect(newProtocolControllerBalanceDth.toString()).to.equal(ethToWei(1));
          expect(newUser6BalanceDth.toString()).to.equal(ethToWei(6));
        });

        it("cannot execute proposal that was already executed", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7*24*60*60);

          await votingInstance.execute(1, { from: user3 });

          // try to execute again

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            'proposal already executed'
          )
        });
      });
    });
  });
});
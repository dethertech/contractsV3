/* eslint-env mocha */
/* global artifacts, contract */
/* eslint-disable max-len, no-multi-spaces, no-unused-expressions */

const { expectEvent } = require("@openzeppelin/test-helpers");

const DetherToken = artifacts.require("DetherToken");
const AnyswapV4ERC20 = artifacts.require("AnyswapV4ERC20");
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
const {
  ethToWei,
  asciiToHex,
  str,
  weiToEth,
  toVotingPerc,
} = require("./utils/convert");
const { expectRevert2 } = require("./utils/evmErrors");

const web3 = new Web3("http://localhost:8545");
const timeTravel = new TimeTravel(web3);

const getBlockTimestamp = async (nr) => (await web3.eth.getBlock(nr)).timestamp;

const PROPOSAL_KIND = {
  GlobalParams: 0,
  CountryFloorPrice: 1,
  SendDth: 2,
};

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
  let tempDthInstance;
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

    tempDthInstance = await DetherToken.new({ from: owner });
    await tempDthInstance.mint(owner, ethToWei(150000), { from: owner });
    await tempDthInstance.mint(user1, ethToWei(150000), { from: owner });
    await tempDthInstance.mint(user2, ethToWei(150000), { from: owner });
    await tempDthInstance.mint(user3, ethToWei(150000), { from: owner });
    await tempDthInstance.mint(user4, ethToWei(150000), { from: owner });
    await tempDthInstance.mint(user5, ethToWei(150000), { from: owner });
    dthInstance = await AnyswapV4ERC20.new(
      "ANYDTH",
      "DTH",
      18,
      tempDthInstance.address,
      owner,
      { from: owner }
    );
    await tempDthInstance.approve(
      dthInstance.address,
      web3.utils.toWei("1000000", "ether"),
      { from: owner }
    );
    await tempDthInstance.approve(
      dthInstance.address,
      web3.utils.toWei("1000000", "ether"),
      { from: user1 }
    );
    await tempDthInstance.approve(
      dthInstance.address,
      web3.utils.toWei("1000000", "ether"),
      { from: user2 }
    );
    await tempDthInstance.approve(
      dthInstance.address,
      web3.utils.toWei("1000000", "ether"),
      { from: user3 }
    );
    await tempDthInstance.approve(
      dthInstance.address,
      web3.utils.toWei("1000000", "ether"),
      { from: user4 }
    );
    await tempDthInstance.approve(
      dthInstance.address,
      web3.utils.toWei("1000000", "ether"),
      { from: user5 }
    );
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

    dthWrapperInstance = await DthWrapper.new(dthInstance.address, {
      from: owner,
    });
    votingInstance = await Voting.new(
      dthWrapperInstance.address,
      toVotingPerc(25), // % of possible votes
      toVotingPerc(60), // % of casted votes
      ethToWei(1), // 1 DTH
      7 * 24 * 60 * 60, // 7 days
      { from: owner }
    );
    protocolControllerInstance = await ProtocolController.new(
      dthInstance.address,
      votingInstance.address,
      geoInstance.address,
      { from: owner }
    );
    await votingInstance.setProtocolController(
      protocolControllerInstance.address,
      { from: owner }
    );

    zoneFactoryInstance = await ZoneFactory.new(
      dthInstance.address,
      geoInstance.address,
      usersInstance.address,
      zoneImplementationInstance.address,
      tellerImplementationInstance.address,
      protocolControllerInstance.address,
      { from: owner }
    );

    await addCountry(owner, web3, geoInstance, "CG", 300);

    await dthInstance.deposit(ethToWei(100), owner, {
      from: owner,
    });
    await dthInstance.deposit(ethToWei(100), user1, {
      from: user1,
    });
    await dthInstance.deposit(ethToWei(100), user2, {
      from: user2,
    });
    await dthInstance.deposit(ethToWei(100), user3, {
      from: user3,
    });
    await dthInstance.deposit(ethToWei(100), user4, {
      from: user4,
    });
    await dthInstance.deposit(ethToWei(100), user5, {
      from: user5,
    });
  });

  const wrapDth = async (from, amount) => {
    await web3.eth.sendTransaction({
      from,
      to: dthInstance.address,
      data: [
        web3.eth.abi.encodeFunctionSignature(
          "transferAndCall(address,uint256,bytes)"
        ),
        web3.eth.abi
          .encodeParameters(
            ["address", "uint256", "bytes"],
            [dthWrapperInstance.address, ethToWei(amount), `0x`]
          )
          .slice(2),
      ].join(""),
      value: 0,
      gas: 4700000,
    });
    expect((await dthWrapperInstance.balanceOf(from)).toString()).to.equal(
      ethToWei(amount)
    );
  };

  describe("Voting", () => {
    describe("ProposalKind.GlobalParams", () => {
      describe("createProposal()", () => {
        it("cannot create proposal if no wrapped dth", async () => {
          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
                2 * 60 * 60,
                1 * 60 * 60,
                10,
                100,
                40,
              ]),
              { from: user1 }
            ),
            "not enough wrapped dth"
          );
        });

        it("cannot create proposal if less than minimum wrapped dth", async () => {
          await wrapDth(user1, 0.9);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
                2 * 60 * 60,
                1 * 60 * 60,
                10,
                100,
                40,
              ]),
              { from: user1 }
            ),
            "not enough wrapped dth"
          );
        });

        it("success", async () => {
          await wrapDth(user1, 1);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
              2 * 60 * 60,
              1 * 60 * 60,
              10,
              100,
              40,
            ]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.startDate.toString()).to.equal(
            blockTimestamp.toString()
          );
          expect(proposal.snapshotBlock.toString()).to.equal(
            (blockNr - 1).toString()
          );
          expect(proposal.minAcceptQuorum.toString()).to.equal(
            toVotingPerc(25).toString()
          );
          expect(proposal.supportRequired.toString()).to.equal(
            toVotingPerc(60).toString()
          );
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal("0");
          expect(proposal.votingPower.toString()).to.equal(ethToWei(1));
          expect(proposal.kind.toString()).to.equal("0");
        });

        it("cannot create proposal with identical args as existing active proposal", async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
              2 * 60 * 60,
              1 * 60 * 60,
              10,
              100,
              40,
            ]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
                2 * 60 * 60,
                1 * 60 * 60,
                10,
                100,
                40,
              ]),
              { from: user2 }
            ),
            "proposal with same args already exists"
          );
        });

        it("cannot create proposal if user already has active proposal", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
              2 * 60 * 60,
              1 * 60 * 60,
              10,
              100,
              40,
            ]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
                2 * 60 * 60,
                1 * 60 * 60,
                10,
                100,
                40,
              ]),
              { from: user1 }
            ),
            "user already has proposal"
          );
        });

        it("cannot create new proposal if old proposal ended but not yet executed", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
              2 * 60 * 60,
              1 * 60 * 60,
              10,
              100,
              40,
            ]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.GlobalParams,
              encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
                2 * 60 * 60,
                1 * 60 * 60,
                10,
                100,
                40,
              ]),
              { from: user1 }
            ),
            "user already has proposal"
          );
        });

        it("can create new proposal if old proposal ended and was executed", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
              2 * 60 * 60,
              1 * 60 * 60,
              10,
              100,
              40,
            ]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await votingInstance.execute(1, { from: user1 });

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
              2 * 60 * 60,
              1 * 60 * 60,
              10,
              100,
              40,
            ]),
            { from: user1 }
          );
        });
      });

      describe("placeVote()", () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
              2 * 60 * 60,
              1 * 60 * 60,
              10,
              100,
              40,
            ]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.startDate.toString()).to.equal(
            blockTimestamp.toString()
          );
          expect(proposal.snapshotBlock.toString()).to.equal(
            (blockNr - 1).toString()
          );
          expect(proposal.minAcceptQuorum.toString()).to.equal(
            toVotingPerc(25).toString()
          );
          expect(proposal.supportRequired.toString()).to.equal(
            toVotingPerc(60).toString()
          );
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal("0");
          expect(proposal.votingPower.toString()).to.equal(ethToWei(2));
          expect(proposal.kind.toString()).to.equal("0");
        });

        it("cannot vote on nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.placeVote(99, true, { from: user2 }),
            "proposal does not exist"
          );
        });

        it("cannot vote on proposal that ended", async () => {
          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            "proposal ended"
          );
        });

        it("cannot vote without wrapped dth", async () => {
          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user3 }),
            "caller does not have voting tokens"
          );
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.yea.toString()).to.equal(ethToWei(1));
          expect(proposal.nay.toString()).to.equal("0");
        });

        it("cannot vote the same side again", async () => {
          await votingInstance.placeVote(1, true, { from: user2 }),
            await expectRevert2(
              votingInstance.placeVote(1, true, { from: user2 }),
              "already voted that side"
            );
        });

        it("can change existing vote's side", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          await votingInstance.placeVote(1, false, { from: user2 });
          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal(ethToWei(1));
        });
      });

      describe("execute()", () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);
          await wrapDth(user3, 2);
          await wrapDth(user4, 2);
          await wrapDth(user5, 4);

          await votingInstance.createProposal(
            PROPOSAL_KIND.GlobalParams,
            encodeProposalArgs(PROPOSAL_KIND.GlobalParams, [
              2 * 60 * 60,
              1 * 60 * 60,
              10,
              100,
              40,
            ]),
            { from: user1 }
          );
        });

        it("cannot execute nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.execute(99, { from: user2 }),
            "proposal does not exist"
          );
        });

        it("cannot execute proposal that did not yet end", async () => {
          await expectRevert2(
            votingInstance.execute(1, { from: user2 }),
            "proposal did not yet end"
          );
        });

        it("can execute proposal with not enough % of casted votes, but doesn't perform the action", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, false, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 50% yea, 50% nay

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          const tx = await votingInstance.execute(1, { from: user3 });

          await expectEvent.inTransaction(
            tx.receipt.transactionHash,
            votingInstance,
            "ProposalFailed",
            { proposalId: "1" }
          );

          expect(
            (await votingInstance.getProposal("1")).state.toString()
          ).to.equal("2");
        });

        it("cannot execute proposal with that did not enough % of possible votes", async () => {
          await votingInstance.placeVote(1, false, { from: user1 });
          await votingInstance.placeVote(1, true, { from: user3 });
          // casted votes = 66% yea, 33% nay
          // possible votes = 20% yea

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          const tx = await votingInstance.execute(1, { from: user3 });

          await expectEvent.inTransaction(
            tx.receipt.transactionHash,
            votingInstance,
            "ProposalFailed",
            { proposalId: "1" }
          );

          expect(
            (await votingInstance.getProposal("1")).state.toString()
          ).to.equal("2");
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          let proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.state.toString()).to.equal("0");

          const oldGlobalParams =
            await protocolControllerInstance.globalParams();
          expect(oldGlobalParams.bidPeriod.toString()).to.equal(
            (48 * 60 * 60).toString()
          );
          expect(oldGlobalParams.cooldownPeriod.toString()).to.equal(
            (24 * 60 * 60).toString()
          );
          expect(oldGlobalParams.entryFee.toString()).to.equal((4).toString());
          expect(oldGlobalParams.zoneTax.toString()).to.equal((4).toString());
          expect(oldGlobalParams.minRaise.toString()).to.equal((6).toString());

          await votingInstance.execute(1, { from: user3 });

          proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.state.toString()).to.equal("1");
          expect(proposal.yea.toString()).to.equal(ethToWei(7));
          expect(proposal.nay.toString()).to.equal(ethToWei(3));
          expect(proposal.votingPower.toString()).to.equal(ethToWei(10));

          const newGlobalParams =
            await protocolControllerInstance.globalParams();
          expect(newGlobalParams.bidPeriod.toString()).to.equal(
            (2 * 60 * 60).toString()
          );
          expect(newGlobalParams.cooldownPeriod.toString()).to.equal(
            (1 * 60 * 60).toString()
          );
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

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await votingInstance.execute(1, { from: user3 });

          // try to execute again

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            "proposal already executed"
          );
        });
      });
    });
    describe("ProposalKind.CountryFloorPrice", () => {
      describe("createProposal()", () => {
        it("cannot create proposal if no wrapped dth", async () => {
          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
                asciiToHex("CG"),
                ethToWei(7),
              ]),
              { from: user1 }
            ),
            "not enough wrapped dth"
          );
        });

        it("cannot create proposal if less than minimum wrapped dth", async () => {
          await wrapDth(user1, 0.9);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
                asciiToHex("CG"),
                ethToWei(7),
              ]),
              { from: user1 }
            ),
            "not enough wrapped dth"
          );
        });

        it("success", async () => {
          await wrapDth(user1, 1);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
              asciiToHex("CG"),
              ethToWei(7),
            ]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.startDate.toString()).to.equal(
            blockTimestamp.toString()
          );
          expect(proposal.snapshotBlock.toString()).to.equal(
            (blockNr - 1).toString()
          );
          expect(proposal.minAcceptQuorum.toString()).to.equal(
            toVotingPerc(25).toString()
          );
          expect(proposal.supportRequired.toString()).to.equal(
            toVotingPerc(60).toString()
          );
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal("0");
          expect(proposal.votingPower.toString()).to.equal(ethToWei(1));
          expect(proposal.kind.toString()).to.equal("1");
        });

        it("cannot create proposal with identical args as existing active proposal", async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
              asciiToHex("CG"),
              ethToWei(7),
            ]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
                asciiToHex("CG"),
                ethToWei(7),
              ]),
              { from: user2 }
            ),
            "proposal with same args already exists"
          );
        });

        it("cannot create proposal if user already has active proposal", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
              asciiToHex("CG"),
              ethToWei(7),
            ]),
            { from: user1 }
          );

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
                asciiToHex("CG"),
                ethToWei(7),
              ]),
              { from: user1 }
            ),
            "user already has proposal"
          );
        });

        it("cannot create new proposal if old proposal ended but not yet executed", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
              asciiToHex("CG"),
              ethToWei(7),
            ]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.CountryFloorPrice,
              encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
                asciiToHex("CG"),
                ethToWei(7),
              ]),
              { from: user1 }
            ),
            "user already has proposal"
          );
        });

        it("can create new proposal if old proposal ended and was executed", async () => {
          await wrapDth(user1, 1);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
              asciiToHex("CG"),
              ethToWei(7),
            ]),
            { from: user1 }
          );

          await votingInstance.placeVote(1, true, { from: user1 });

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await votingInstance.execute(1, { from: user1 });

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
              asciiToHex("CG"),
              ethToWei(7),
            ]),
            { from: user1 }
          );
        });
      });

      describe("placeVote()", () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);

          const tx = await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
              asciiToHex("CG"),
              ethToWei(7),
            ]),
            { from: user1 }
          );

          const blockNr = tx.receipt.blockNumber;
          const blockTimestamp = await getBlockTimestamp(blockNr);

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.startDate.toString()).to.equal(
            blockTimestamp.toString()
          );
          expect(proposal.snapshotBlock.toString()).to.equal(
            (blockNr - 1).toString()
          );
          expect(proposal.minAcceptQuorum.toString()).to.equal(
            toVotingPerc(25).toString()
          );
          expect(proposal.supportRequired.toString()).to.equal(
            toVotingPerc(60).toString()
          );
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal("0");
          expect(proposal.votingPower.toString()).to.equal(ethToWei(2));
          expect(proposal.kind.toString()).to.equal("1");
        });

        it("cannot vote on nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.placeVote(99, true, { from: user2 }),
            "proposal does not exist"
          );
        });

        it("cannot vote on proposal that ended", async () => {
          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            "proposal ended"
          );
        });

        it("cannot vote without wrapped dth", async () => {
          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user3 }),
            "caller does not have voting tokens"
          );
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.yea.toString()).to.equal(ethToWei(1));
          expect(proposal.nay.toString()).to.equal("0");
        });

        it("cannot vote the same side again", async () => {
          await votingInstance.placeVote(1, true, { from: user2 }),
            await expectRevert2(
              votingInstance.placeVote(1, true, { from: user2 }),
              "already voted that side"
            );
        });

        it("can change existing vote's side", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          await votingInstance.placeVote(1, false, { from: user2 });
          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal(ethToWei(1));
        });
      });

      describe("execute()", () => {
        beforeEach(async () => {
          await wrapDth(user1, 1);
          await wrapDth(user2, 1);
          await wrapDth(user3, 2);
          await wrapDth(user4, 2);
          await wrapDth(user5, 4);

          await votingInstance.createProposal(
            PROPOSAL_KIND.CountryFloorPrice,
            encodeProposalArgs(PROPOSAL_KIND.CountryFloorPrice, [
              asciiToHex("CG"),
              ethToWei(7),
            ]),
            { from: user1 }
          );
        });

        it("cannot execute nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.execute(99, { from: user2 }),
            "proposal does not exist"
          );
        });

        it("cannot execute proposal that did not yet end", async () => {
          await expectRevert2(
            votingInstance.execute(1, { from: user2 }),
            "proposal did not yet end"
          );
        });

        it("can execute proposal with not enough % of casted votes, but doesn't perform the action", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, false, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 50% yea, 50% nay

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          const tx = await votingInstance.execute(1, { from: user3 });

          await expectEvent.inTransaction(
            tx.receipt.transactionHash,
            votingInstance,
            "ProposalFailed",
            { proposalId: "1" }
          );

          expect(
            (await votingInstance.getProposal("1")).state.toString()
          ).to.equal("2");
        });

        it("can execute proposal with that did not enough % of possible votes, but doesn't perform the action", async () => {
          await votingInstance.placeVote(1, false, { from: user1 });
          await votingInstance.placeVote(1, true, { from: user3 });
          // casted votes = 66% yea, 33% nay
          // possible votes = 20% yea

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          const tx = await votingInstance.execute(1, { from: user3 });

          await expectEvent.inTransaction(
            tx.receipt.transactionHash,
            votingInstance,
            "ProposalFailed",
            { proposalId: "1" }
          );

          expect(
            (await votingInstance.getProposal("1")).state.toString()
          ).to.equal("2");
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          let proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.state.toString()).to.equal("0");

          const oldCountryFloorPrice =
            await protocolControllerInstance.getCountryFloorPrice(
              asciiToHex("CG")
            );
          expect(oldCountryFloorPrice.toString()).to.equal(ethToWei(100));

          await votingInstance.execute(1, { from: user3 });

          proposal = await votingInstance.getProposal(1);
          expect(proposal.state.toString()).to.equal("1");
          expect(proposal.open).to.equal(false);
          expect(proposal.state.toString()).to.equal("1");
          expect(proposal.yea.toString()).to.equal(ethToWei(7));
          expect(proposal.nay.toString()).to.equal(ethToWei(3));
          expect(proposal.votingPower.toString()).to.equal(ethToWei(10));

          const newCountryFloorPrice =
            await protocolControllerInstance.getCountryFloorPrice(
              asciiToHex("CG")
            );
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

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await votingInstance.execute(1, { from: user3 });

          // try to execute again

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            "proposal already executed"
          );
        });
      });
    });
    describe("ProposalKind.SendDth", () => {
      const payTaxesToProtocolController = async (from, amount) => {
        await web3.eth.sendTransaction({
          from,
          to: dthInstance.address,
          data: [
            web3.eth.abi.encodeFunctionSignature(
              "transferAndCall(address,uint256,bytes)"
            ),
            web3.eth.abi
              .encodeParameters(
                ["address", "uint256", "bytes"],
                [protocolControllerInstance.address, ethToWei(amount), `0x`]
              )
              .slice(2),
          ].join(""),
          value: 0,
          gas: 4700000,
        });
        expect(
          (
            await dthInstance.balanceOf(protocolControllerInstance.address)
          ).toString()
        ).to.equal(ethToWei(amount));
      };
      describe("createProposal()", () => {
        it("cannot create proposal if no wrapped dth", async () => {
          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.SendDth,
              encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
              { from: user1 }
            ),
            "not enough wrapped dth"
          );
        });

        it("cannot create proposal if less than minimum wrapped dth", async () => {
          await wrapDth(user1, 0.9);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.SendDth,
              encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
              { from: user1 }
            ),
            "not enough wrapped dth"
          );
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
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.startDate.toString()).to.equal(
            blockTimestamp.toString()
          );
          expect(proposal.snapshotBlock.toString()).to.equal(
            (blockNr - 1).toString()
          );
          expect(proposal.minAcceptQuorum.toString()).to.equal(
            toVotingPerc(25).toString()
          );
          expect(proposal.supportRequired.toString()).to.equal(
            toVotingPerc(60).toString()
          );
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal("0");
          expect(proposal.votingPower.toString()).to.equal(ethToWei(1));
          expect(proposal.kind.toString()).to.equal("2");
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
            "proposal with same args already exists"
          );
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
            "user already has proposal"
          );
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

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await expectRevert2(
            votingInstance.createProposal(
              PROPOSAL_KIND.SendDth,
              encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
              { from: user1 }
            ),
            "user already has proposal"
          );
        });

        it("can create new proposal if existing proposal ended, didnt get enough support, but was executed", async () => {
          await wrapDth(user1, 1);

          await payTaxesToProtocolController(user1, 7);

          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(6)]),
            { from: user1 }
          );

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          const tx = await votingInstance.execute(1, { from: user1 });

          await expectEvent.inTransaction(
            tx.receipt.transactionHash,
            votingInstance,
            "ProposalFailed",
            { proposalId: "1" }
          );
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

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await votingInstance.execute(1, { from: user1 });

          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(1)]),
            { from: user1 }
          );
        });
      });

      describe("placeVote()", () => {
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
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.startDate.toString()).to.equal(
            blockTimestamp.toString()
          );
          expect(proposal.snapshotBlock.toString()).to.equal(
            (blockNr - 1).toString()
          );
          expect(proposal.minAcceptQuorum.toString()).to.equal(
            toVotingPerc(25).toString()
          );
          expect(proposal.supportRequired.toString()).to.equal(
            toVotingPerc(60).toString()
          );
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal("0");
          expect(proposal.votingPower.toString()).to.equal(ethToWei(2));
          expect(proposal.kind.toString()).to.equal("2");
        });

        it("cannot vote on nonexistent proposal", async () => {
          await expectRevert2(
            votingInstance.placeVote(99, true, { from: user2 }),
            "proposal does not exist"
          );
        });

        it("cannot vote on proposal that ended", async () => {
          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user2 }),
            "proposal ended"
          );
        });

        it("cannot vote without wrapped dth", async () => {
          await expectRevert2(
            votingInstance.placeVote(1, true, { from: user3 }),
            "caller does not have voting tokens"
          );
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.yea.toString()).to.equal(ethToWei(1));
          expect(proposal.nay.toString()).to.equal("0");
        });

        it("cannot vote the same side again", async () => {
          await votingInstance.placeVote(1, true, { from: user2 }),
            await expectRevert2(
              votingInstance.placeVote(1, true, { from: user2 }),
              "already voted that side"
            );
        });

        it("can change existing vote's side", async () => {
          await votingInstance.placeVote(1, true, { from: user2 });

          await votingInstance.placeVote(1, false, { from: user2 });
          const proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");
          expect(proposal.yea.toString()).to.equal("0");
          expect(proposal.nay.toString()).to.equal(ethToWei(1));
        });
      });

      describe("execute()", () => {
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
            "proposal does not exist"
          );
        });

        it("cannot execute proposal that did not yet end", async () => {
          await expectRevert2(
            votingInstance.execute(1, { from: user2 }),
            "proposal did not yet end"
          );
        });

        it("can execute proposal with not enough % of casted votes, but doesn't perform the action", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, false, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 50% yea, 50% nay

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          const tx = await votingInstance.execute(1, { from: user3 });

          await expectEvent.inTransaction(
            tx.receipt.transactionHash,
            votingInstance,
            "ProposalFailed",
            { proposalId: "1" }
          );

          expect(
            (await votingInstance.getProposal("1")).state.toString()
          ).to.equal("2");
        });

        it("can execute proposal with not enough % of possible votes, but doesn't perform the action", async () => {
          await votingInstance.placeVote(1, false, { from: user1 });
          await votingInstance.placeVote(1, true, { from: user3 });
          // casted votes = 66% yea, 33% nay
          // possible votes = 20% yea

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          const tx = await votingInstance.execute(1, { from: user3 });

          await expectEvent.inTransaction(
            tx.receipt.transactionHash,
            votingInstance,
            "ProposalFailed",
            { proposalId: "1" }
          );

          expect(
            (await votingInstance.getProposal("1")).state.toString()
          ).to.equal("2");
        });

        it("success", async () => {
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          let proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.state.toString()).to.equal("0");

          const oldProtocolControllerBalanceDth = (
            await dthInstance.balanceOf(protocolControllerInstance.address)
          ).toString();
          const oldUser6BalanceDth = (
            await dthInstance.balanceOf(user6)
          ).toString();
          expect(oldProtocolControllerBalanceDth.toString()).to.equal(
            ethToWei(7)
          );
          expect(oldUser6BalanceDth.toString()).to.equal(ethToWei(0));

          await votingInstance.execute(1, { from: user3 });

          proposal = await votingInstance.getProposal(1);
          expect(proposal.state.toString()).to.equal("1");
          expect(proposal.open).to.equal(false);
          expect(proposal.yea.toString()).to.equal(ethToWei(7));
          expect(proposal.nay.toString()).to.equal(ethToWei(3));
          expect(proposal.votingPower.toString()).to.equal(ethToWei(10));

          const newProtocolControllerBalanceDth = (
            await dthInstance.balanceOf(protocolControllerInstance.address)
          ).toString();
          const newUser6BalanceDth = (
            await dthInstance.balanceOf(user6)
          ).toString();
          expect(newProtocolControllerBalanceDth.toString()).to.equal(
            ethToWei(1)
          );
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

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          await votingInstance.execute(1, { from: user3 });

          // try to execute again

          await expectRevert2(
            votingInstance.execute(1, { from: user3 }),
            "proposal already executed"
          );
        });

        it("can execute even if there is not enough dth in ProtocolController", async () => {
          await votingInstance.createProposal(
            PROPOSAL_KIND.SendDth,
            encodeProposalArgs(PROPOSAL_KIND.SendDth, [user6, ethToWei(5)]),
            { from: user2 }
          );
          await votingInstance.placeVote(1, true, { from: user1 });
          await votingInstance.placeVote(1, false, { from: user2 });
          await votingInstance.placeVote(1, false, { from: user3 });
          await votingInstance.placeVote(1, true, { from: user4 });
          await votingInstance.placeVote(1, true, { from: user5 });

          await votingInstance.placeVote(2, true, { from: user1 });
          await votingInstance.placeVote(2, false, { from: user2 });
          await votingInstance.placeVote(2, false, { from: user3 });
          await votingInstance.placeVote(2, true, { from: user4 });
          await votingInstance.placeVote(2, true, { from: user5 });
          // casted votes = 70% yea, 30% nay
          // possible votes = 70% yea

          let proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");

          proposal = await votingInstance.getProposal(2);
          expect(proposal.open).to.equal(true);
          expect(proposal.state.toString()).to.equal("0");

          await timeTravel.inSecs(7 * 24 * 60 * 60);

          const oldProtocolControllerBalanceDth = (
            await dthInstance.balanceOf(protocolControllerInstance.address)
          ).toString();
          const oldUser6BalanceDth = (
            await dthInstance.balanceOf(user6)
          ).toString();
          expect(oldProtocolControllerBalanceDth.toString()).to.equal(
            ethToWei(7)
          );
          expect(oldUser6BalanceDth.toString()).to.equal(ethToWei(0));

          proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.state.toString()).to.equal("0");

          await votingInstance.execute(1, { from: user3 });

          proposal = await votingInstance.getProposal(1);
          expect(proposal.open).to.equal(false);
          expect(proposal.state.toString()).to.equal("1");

          const newProtocolControllerBalanceDth_1 = (
            await dthInstance.balanceOf(protocolControllerInstance.address)
          ).toString();
          const newUser6BalanceDth_1 = (
            await dthInstance.balanceOf(user6)
          ).toString();
          expect(newProtocolControllerBalanceDth_1.toString()).to.equal(
            ethToWei(1)
          );
          expect(newUser6BalanceDth_1.toString()).to.equal(ethToWei(6));

          // there is not enough Dth left in ProtocolController, however the execute call will still succeed
          const tx = await votingInstance.execute(2, { from: user3 });
          // a special evne twill be emitted to indicate the dth transfer failed
          await expectEvent.inTransaction(
            tx.receipt.transactionHash,
            protocolControllerInstance,
            "WithdrawDthTransferFailed",
            { recipient: user6, amount: ethToWei(5) }
          );

          proposal = await votingInstance.getProposal(2);
          expect(proposal.open).to.equal(false);
          expect(proposal.state.toString()).to.equal("1");

          const newProtocolControllerBalanceDth_2 = (
            await dthInstance.balanceOf(protocolControllerInstance.address)
          ).toString();
          const newUser6BalanceDth_2 = (
            await dthInstance.balanceOf(user6)
          ).toString();
          expect(newProtocolControllerBalanceDth_2.toString()).to.equal(
            ethToWei(1)
          );
          expect(newUser6BalanceDth_2.toString()).to.equal(ethToWei(6));
        });
      });
    });
  });
});

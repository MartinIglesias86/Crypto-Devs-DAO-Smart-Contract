// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

//interface for the FakeNFTMarketplace contract
interface IFakeNFTMarketplace {
    //@dev getPrice() returns the price of an NFT from the FakeNFTMarketplace
    //@return returns the price in Wei for an NFT
    function getPrice() external view returns (uint256);
    
    //@dev available() returns whether or not the given _tokenId has already been purchased
    //@return returns a boolean - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);

    //@dev purchase() purchases an NFT from the FakeNFTMarketplace
    //@param _tokeId - the  fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}
/*
Minimal interface for CryptoDevsNFT containing only two functions
that we are interested in
*/
interface ICryptoDevsNFT {
    //@dev balanceOf returns the number of NFTs owned by the given address
    //@param owner - address to fetch the number of NFTs for
    //@return returns the number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    //@dev tokenOfOwnerByIndex returns a tokenID at given index for owner
    //@param owner - address to fetch the NFT TokenID for
    //@param index - index of NFT in owned tokens array to fetch
    //@return returns the TokeID of the NFT
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract CryptoDevsDAO is Ownable {
    //create a struct named Proposal containing all relevant information
    struct Proposal {
        //nftTokenId - the tokenIDofthe NFT to purchase from FakeNFTMarketplace if the proposal passes
        uint256 nftTokenId;
        //deadline - the UNIX timestamp until which this proposal is active. Proposal can be executed after the deadline has been exceeded
        uint256 deadline;
        //yayVotes - number of yay votes for this proposal
        uint256 yayVotes;
        //nayVotes - nomber of nay votes for this proposl
        uint256 nayVotes;
        //executed - whether or not this proposal has been executed yet. Cannot be executed before the deadline has been exceeded
        bool executed;
        //voters - a mapping of CryptoDevsNFT tokensIDs to booleans indicating whether that NFT has lredy been used to cst  vote or not
        mapping(uint256 => bool) voters;
    }

    //create a mapping of ID to Proposal
    mapping(uint256 => Proposal) public proposals;
    //number of proposals that have been created
    uint256 public numProposals;

    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    /*
    Create a payable constructor which initiaalizes the contract instances
    for FakeNFTMarketplace and CryptoDevsNFT
    The payable allows this constructor to accept an ETH deposit when it is being deployed
    */
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    //create a modifier which only llows  function to be clles by someone
    //who owns t lest 1 CryptoDevsNFT
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "No es un miembro de la DAO");
        _;
    }

    //@dev createProposal allows a CryptoDevsNFT holder to create a new proposal in the DAO
    //@param _nftTokenId - the tokenID of the NFT to be purchased from FakeNFTMarketplace if this proposal passes
    //@return returns the proposal index for the newly created proposal
    function createProposal(uint256 _nftTokenId) external nftHolderOnly returns (uint256) {
        require(nftMarketplace.available(_nftTokenId), "NFT no a la venta");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        //set the proposal's voting deadline to be (current time + 5 minutes)
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;
        return numProposals -1;
    }

    //create modifier which only allows a function to be called
    //if the given proposal's deadlline has not been excedeed yet
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "Fecha limite excedida"
        );
        _;
    }

    //create a enum named Vote containing possible options for a vote
    enum Vote {
        YAY,
        NAY
    }

    //@dev voteOnProposal allows a CryptoDevsNFT holder to cast their vote on an aactive proposal
    //@param proposalIndex - the index of the proposal to vote on in the proposals array
    //@param vote - the type of vote they want to cast
    function voteOnProposal(uint256 proposalIndex, Vote vote) external nftHolderOnly activeProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];
        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        //calculate how many NFTs are owned by the voter that haven't
        //already been used for voting on this proposal
        for (uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "Ya has votado");

        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    //create modifier which only allows a function to be called if the
    //given proposal's deadline HAS been excedeed and if the proposal
    //has not yet been executed
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "Todavia no finalizo el tiempo de votacion"
        );
        require(
            proposals[proposalIndex].executed == false, 
            "La propuesta ya fue ejecutada"
        );
        _;
    }

    //@dev executeProposal allows any CryptoDevsNFT holder to execute a proposal after it's deadline has been excedeed
    //@param proposalIndex - the index of the proposal to execute in the proposals array
    function executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];
        //if the proposal has more YAY votes than NAY votes, purchase the NFT from th FakeNFTMarketplace
        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "No posee suficientes fondos");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }
    //@dev withdrawEther allows the contract owner (deployer) to withdraw the ETH from the contract
    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    //the following two functions allow the contract to accept ETH deposits
    //directly from a wallet without calling a function
    receive() external payable{}
    fallback() external payable{}
}
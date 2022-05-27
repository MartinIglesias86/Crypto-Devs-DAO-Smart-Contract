// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FakeNFTMarketplace {
    //@dev Maintain a mapping of Fake TokenID to Owner addresses
    mapping(uint256 => address) public tokens;
    //@dev set the purchase price for each Fake NFT
    uint256 nftPrice = 0.01 ether;

    //@dev purchase() accepts ETH and marks the owner of the given tokenId as the caller address
    //@param _tokenId - The Fake TokenID to purchase
    function purchase(uint256 _tokenId) external payable{
        require(msg.value == nftPrice, "Este NFT cuesta 0.1 ether");
        tokens[_tokenId] = msg.sender;
    }

    //@dev getPrice() returns the price of one NFT
    function getPrice() external view returns (uint256){
        return nftPrice;
    }

    //@dev available() checks whether the given tokenId has already been sold or not
    //@param _tokenId - the tokenId to check for
    function available(uint256 _tokenId) external view returns (bool) {
        //address(0) = 0x0000000000000000000000000000000000000000
        //this is the default value for addresses in Solidity
        if (tokens[_tokenId] == address(0)) {
            return true;
        }
        return false;
    }
}
/*
The FakeNFTMarketplace exposes some basic functions that we will be using from the DAO contract
to purchase NFTs if a proposal is passed.
A real NFT marketplace would be more complicated - as not all NFTs have the same price.
*/
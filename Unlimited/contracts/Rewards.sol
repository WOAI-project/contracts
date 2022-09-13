/**

    ░██╗░░░░░░░██╗░█████╗░░█████╗░██╗░░░░██╗██╗░░░██╗███╗░░██╗██╗░░░░░██╗███╗░░░███╗██╗████████╗███████╗██████╗░
    ░██║░░██╗░░██║██╔══██╗██╔══██╗██║░░░██╔╝██║░░░██║████╗░██║██║░░░░░██║████╗░████║██║╚══██╔══╝██╔════╝██╔══██╗
    ░╚██╗████╗██╔╝██║░░██║███████║██║░░██╔╝░██║░░░██║██╔██╗██║██║░░░░░██║██╔████╔██║██║░░░██║░░░█████╗░░██║░░██║
    ░░████╔═████║░██║░░██║██╔══██║██║░██╔╝░░██║░░░██║██║╚████║██║░░░░░██║██║╚██╔╝██║██║░░░██║░░░██╔══╝░░██║░░██║
    ░░╚██╔╝░╚██╔╝░╚█████╔╝██║░░██║██║██╔╝░░░╚██████╔╝██║░╚███║███████╗██║██║░╚═╝░██║██║░░░██║░░░███████╗██████╔╝
    ░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚═╝╚═╝╚═╝░░░░░╚═════╝░╚═╝░░╚══╝╚══════╝╚═╝╚═╝░░░░░╚═╝╚═╝░░░╚═╝░░░╚══════╝╚═════╝░

 */

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/Unlimited.sol";

contract Rewards is Unlimited {

    //BEGIN: VARIABLES
    uint public currentEpoch;
    uint public epochStartTime;
    uint internal pendingRewardsCost;                   //The new rewards cost to be required for mints in the next epoch
    mapping(uint => uint) private epochWinner;          //Mapping for "epoch" to "tokenId"
    mapping(uint => uint) private epochRewards;         //Mapping for "epoch" to "epochRewards"
    mapping(uint => bool) private epochEnded;           //Mapping for "epoch" to "epochEnded"
    //END: VARIABLES

    //Initialisation
    constructor() {
        epochStartTime = block.timestamp;
    }


    //BEGIN: EVENTS
    event AddRewards(uint _epoch, uint _rewardsAdded);
    event EndEpoch(uint _epoch, uint _winner, uint _rewardsClaimable);
    event WithdrawRewards(address indexed _to, uint _epoch, uint _amount);
    //END: EVENTS

    //BEGIN: HELPER FUNCTIONS
    function hasMostVotes() public returns(uint) {
        //return the tokenId with most votes in the current epoch
    }
    function addRewards(uint epoch) payable public {
        require(epoch >= currentEpoch, "Cannot add rewards to epochs that have ended");
        epochRewards[epoch] += msg.value;
    }
    function addRewadsToCurrentEpoch() payable public {
        addRewards(currentEpoch);
    }
    function addRewardsErc20(uint epoch) public {
        require(epoch >= currentEpoch, "Cannot add rewards to epochs that have ended");
        //add ERC20 to the reward contract; needs a withdraw function as well
    }
    function addRewardsErc721(uint epoch) public {
        require(epoch >= currentEpoch, "Cannot add rewards to epochs that have ended");
        //add ERC721 to the reward contract; needs a withdraw function as well
    }
    function endEpoch() public {
        require(block.timestamp - epochStartTime > 28 days);
        epochWinner[currentEpoch] = hasMostVotes();
        epochEnded[currentEpoch] = true;
        Unlimited.rewardsEligibility[hasMostVotes()] = false;  //Same token cannot win twice
        Unlimited.rewardsCost = pendingRewardsCost;
        emit EndEpoch(currentEpoch, epochWinner[currentEpoch], epochRewards[currentEpoch]);
        currentEpoch += 1;
        epochStartTime = block.timestamp;
    }
    //END: HELPER FUNCTIONS

    //BEGIN: ADMIN FUNCTIONS
    function setRewardsCost(uint _wei) public onlyOwner {
        pendingRewardsCost = _wei;
    }
    //END: ADMIN FUNCTIONS

    //BEGIN: USER FUNCTIONS
    function withdrawRewards(uint _epoch) public {
        require(msg.sender == ERC721.ownerOf(epochWinner[_epoch]), "Only the winner of the epoch can withdraw rewards");
        require(epochEnded[_epoch], "Epoch must end before withdrawing rewards");
        payable(msg.sender).transfer(epochRewards[_epoch]);
        emit WithdrawRewards(msg.sender, _epoch, epochRewards[_epoch]);
    }
    function castVote(uint _voteFor, uint _voteWith) public {
        require(_voteFor != _voteWith, "You cannot vote for the same token you are voting with");
        require(Unlimited.mintTime[_voteFor] < epochStartTime, "You cannot vote for tokens minted within the current epoch");
        require(Unlimited.rewardsEligibility[_voteFor] == true, "Token you are voting for is not eligible to receive votes");
        require(ERC721.ownerOf(_voteWith) == msg.sender, "You must own the token you are voting with");
        require(Unlimited.votingEligibility[_voteWith] == true, "Token is not eligible to vote");
        Unlimited.votingEligibility[_voteWith] = false;
        //casts vote in the current epoch to the _voteFor
    }
    function castVoteWithZero(uint _voteFor) public {
        //casts vote in the current epoch to the _voteFor
        // _voteFor != _voteWith
        //_voteFor must have been minted in the previous epoch
        //_voteFor must have rewardsEligibility == true
    }
    //END: USER FUNCTIONS
}
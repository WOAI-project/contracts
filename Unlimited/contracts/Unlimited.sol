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

contract Unlimited is ERC721, Ownable {

    using Counters for Counters.Counter;

    //BEGIN: VARIABLES
    //Metadata fields
    string private baseUri = "https://woai-data.woai.io/unlimited/";
    string private baseExtension = ".json";
    mapping(uint => uint) public engineUsed;          //Maps "tokenId" to "engineId"
    mapping(uint => string) public generatorValue;       //Maps "tokenId" to "generatorValue"
    mapping(uint => string) public tokenName;            //Maps "tokenId" to "tokenName" (optional) (let's minter choose NFT display name)

    //Engines
    mapping(uint => string) public engineName;           //Maps an "engineId" to "engineName"

    //Statuses & Compatibility
    bool public saleActive = false;
    Counters.Counter private _supply;                   //Keeps count of the total supply, net of burned
    Counters.Counter private _idCounter;                //Keeps count of the next tokenId to be given

    //Pricing
    mapping(uint => uint) private engineCost;             //Set in USD
    uint private marginPercentage = 30;
    uint private vatPercentage = 24;

    //Balances
    uint private contractBalance;

    //Rewards logic
    uint public rewardsCost = 5e15;                     //Set in wei
    mapping(uint => bool) internal rewardsEligibility;    //Maps "tokenId" to a boolean (true if the tokenId can win rewards)
    mapping(uint => bool) internal votingEligibility;     //Maps "tokenId" to a boolean (true if the tokenId can vote)
    mapping(uint => uint) internal mintTime;              //Maps "tokenId" to a block timestamp
    //END: VARIABLES

    //Initialisation
    constructor() ERC721("World of AI/Unlimited","WOAI/U") {
    }



    //BEGIN: ADMIN FUNCTIONS
    /**
    * @dev changes the sale state; hence (dis)allowsing minting on the front-end
    * front-end error messages should be derived from this property
    */
    function toggleSaleState() public onlyOwner {
        saleActive = !saleActive;
    }
    /**
    * @dev sets the base URI for metadata
    */
    function setBaseUri(string memory newBaseUri) public onlyOwner {
        baseUri = newBaseUri;
    }
    /**
    * @dev withdraws ether from the contract
    */
    function withdraw() external onlyOwner {
        (bool sent, ) = payable(owner()).call{ value: contractBalance }("");
		require(sent, "Withdrawal failed");
    }
    //Add: safety function to withdraw any ERC20, 721, etc that is not associated with an epoch
    //END: ADMIN FUNCTIONS


    //BEGIN: UNIVERSAL HELPER/COMPATIBILITY FUNCTIONS
    /**
    * @dev returns current total supply of WOAI/U
    */
    function totalSupply() public view returns(uint) {
        return _supply.current();
    }
    /**
    * @dev returns the URI of a given token
    */
    function tokenURI(uint256 tokenId) public view override returns(string memory){
        require(_exists(tokenId), "Token does not exist");
        return string(abi.encodePacked(baseUri, tokenId, baseExtension));
    }
    //END: UNIVERSAL HELPER/COMPATIBILITY FUNCTIONS


    //BEGIN: UNLIMITED-SPECIFIC HELPER/COMPATIBILITY FUNCTIONS
    function getMintPriceWithRewards(uint engineId) public view returns(uint) {
    }
    function getMintPriceWithoutRewards(uint engineId) public view returns(uint) {}
    function getEngineCost(uint _engineId) public view returns(uint) {
        return engineCost[_engineId];
    }
    //END: UNLIMITED-SPECIFIC HELPER/COMPATIBILITY FUNCTIONS


    //BEGIN: EVENTS
    event MintWithRewards(address indexed _from, uint _tokenId, uint _engineId, string _generatorValue, string _tokenName);
    event MintWithoutRewards(address indexed _from, uint _tokenId, uint _engineId, string _generatorValue, string _tokenName);
    event BurnToken(address indexed _from, uint _tokenId);
    //END: EVENTS

    //BEGIN: USER FUNCTIONS
    function mintWithRewards(uint _engineId, string memory _generatorValue, string memory _tokenName) external payable {
        require(saleActive, "Minting disabled");
        require(msg.value >= getMintPriceWithRewards(_engineId),"Not enough Ether");
        contractBalance += msg.value - rewardsCost;
        _supply.increment();
        _idCounter.increment();
        _safeMint(msg.sender, _idCounter.current());
        engineUsed[_idCounter.current()] = _engineId;
        generatorValue[_idCounter.current()] = _generatorValue;
        tokenName[_idCounter.current()] = _tokenName;
        rewardsEligibility[_idCounter.current()] = true;
        votingEligibility[_idCounter.current()] = true;
        mintTime[_idCounter.current()] = block.timestamp;
        //send rewardsCost to rewardsContract (to current epoch --> mints in this epoch, add to rewards of this epoch)
        emit MintWithRewards(msg.sender, _idCounter.current(), _engineId, _generatorValue, _tokenName);
    }
    function mintWithoutRewards(uint _engineId, string memory _generatorValue, string memory _tokenName) external payable {
        require(saleActive, "Minting disabled");
        require(msg.value >= getMintPriceWithoutRewards(_engineId),"Not enough Ether");
        contractBalance += msg.value;
        _supply.increment();
        _idCounter.increment();
        _safeMint(msg.sender, _idCounter.current());
        engineUsed[_idCounter.current()] = _engineId;
        generatorValue[_idCounter.current()] = _generatorValue;
        tokenName[_idCounter.current()] = _tokenName;
        rewardsEligibility[_idCounter.current()] = false;
        votingEligibility[_idCounter.current()] = false;
        emit MintWithoutRewards(msg.sender, _idCounter.current(), _engineId, _generatorValue, _tokenName);
    }
    function burnToken(uint _tokenId) external {
        require(msg.sender == ERC721.ownerOf(_tokenId), "Only the token owner can burn it!");
        ERC721._burn(_tokenId);
        _supply.decrement();
        emit BurnToken(msg.sender, _tokenId);
    }
    //END: USER FUNCTIONS

}
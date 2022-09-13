/**

    ░██╗░░░░░░░██╗░█████╗░░█████╗░██╗░░░░██╗██╗░░░██╗███╗░░██╗██╗░░░░░██╗███╗░░░███╗██╗████████╗███████╗██████╗░
    ░██║░░██╗░░██║██╔══██╗██╔══██╗██║░░░██╔╝██║░░░██║████╗░██║██║░░░░░██║████╗░████║██║╚══██╔══╝██╔════╝██╔══██╗
    ░╚██╗████╗██╔╝██║░░██║███████║██║░░██╔╝░██║░░░██║██╔██╗██║██║░░░░░██║██╔████╔██║██║░░░██║░░░█████╗░░██║░░██║
    ░░████╔═████║░██║░░██║██╔══██║██║░██╔╝░░██║░░░██║██║╚████║██║░░░░░██║██║╚██╔╝██║██║░░░██║░░░██╔══╝░░██║░░██║
    ░░╚██╔╝░╚██╔╝░╚█████╔╝██║░░██║██║██╔╝░░░╚██████╔╝██║░╚███║███████╗██║██║░╚═╝░██║██║░░░██║░░░███████╗██████╔╝
    ░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚═╝╚═╝╚═╝░░░░░╚═════╝░╚═╝░░╚══╝╚══════╝╚═╝╚═╝░░░░░╚═╝╚═╝░░░╚═╝░░░╚══════╝╚═════╝░

    READ THE TERMS AND CONDITIONS AT http://woai-data.woai.io/terms.html CAREFULLY BEFORE CONFIRMING
    YOUR INTENT TO BE BOUND BY THEM. WOAI RESERVES THE RIGHT AT ANY TIME, AND FROM TIME TO TIME, TO
    CHANGE THE TERMS AND CONDITIONS OF THIS NFT CONTRACT WITHOUT NOTICE TO THE NFT HOLDER(S).

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
    bool public contractActive = false;                 //Enables suspension of minting
    Counters.Counter private _supply;                   //Keeps count of the total supply, net of burned
    Counters.Counter private _idCounter;                //Keeps count of the next tokenId to be given

    //Pricing
    mapping(uint => uint) private engineCost;             //Set in USD -- NOTICE: CURRENTLY ASSUMES ETHER IN CONTRACTS
    uint public marginPercentage = 15;
    uint public vatPercentage = 24;
    uint public teamPercentage = 15;

    //Balances
    uint public opexBalance;
    uint public teamBalance;
    address public teamWithdrawalAddress;

    //Rewards logic
    uint public rewardsCost = 5e15;                       //Set in wei
    mapping(uint => bool) internal rewardsEligibility;    //Maps "tokenId" to a boolean (true if the tokenId can win rewards)
    mapping(uint => bool) internal votingEligibility;     //Maps "tokenId" to a boolean (true if the tokenId can vote)
    mapping(uint => uint) internal mintTime;              //Maps "tokenId" to a block timestamp
    //END: VARIABLES

    //Initialisation
    constructor() ERC721("World of AI/Unlimited","WOAI/U") {
    }



    //BEGIN: ADMIN FUNCTIONS
    /**
    * @dev (dis)allows minting new Unlimiteds
    */
    function toggleContractOnOff() public onlyOwner {
        contractActive = !contractActive;
    }
    /**
    * @dev sets the base URI for metadata
    */
    function setBaseUri(string memory newBaseUri) public onlyOwner {
        baseUri = newBaseUri;
    }
    /**
    * @dev withdraws ether associated to OpEx from the contract
    */
    function withdrawOpex() external onlyOwner {
        (bool sent, ) = payable(owner()).call{ value: opexBalance }("");
		require(sent, "Withdrawal failed");
    }
    /**
    * @dev withdraws ether assigned to the team from the contract
    */
    function withdrawTeam() external onlyOwner {
        (bool sent, ) = payable(teamWithdrawalAddress).call{ value: teamBalance }("");
		require(sent, "Withdrawal failed");
    }
    /**
    * @dev sets the team withdrawal address
    */
    function setTeamWithdrawalAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0));
        teamWithdrawalAddress = _newAddress;
        return _newAddress;
    }
    /**
    * @dev sets engine name in the engineId -> engineName mapping. N.B. when minting, engineId is not checked against
    * existing engines; if called with wrong engineId it will be ignored
    */
    function setEngineName(uint _engineId, string _engineName) external onlyOwner {
        engineName[_engineId] = _engineName;
    }
    /**
    * @dev sets the VAT percentage (must be % (e.g. 1% = 1))
    */
    function setVatPercentage(uint _newVatPercentage) external onlyOwner {
        vatPercentage = _newVatPercentage;
    }
    /**
    * @dev sets a new margin percentage (must be % (e.g. 1% = 1))
    */
    function setMarginPercentage(uint _newMarginPercentage) external onlyOwner {
        marginPercentage = _newMarginPercentage;
    }
    /**
    * @dev sets a new team percentage (must be % (e.g. 1% = 1))
    */
    function setTeamPercentage(uint _newTeamPercentage) external onlyOwner {
        teamPercentage = _newTeamPercentage;
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
    function opexPrice(uint engineId) internal view returns(uint) {
        return engineCost[engineId] * (1 + marginPercentage/100);
    }
    function teamPrice(uint engineId) internal view returns(uint) {
        return engineCost[engineId] * (teamPercentage/100);
    }
    function getPriceWithVat(uint engineId) internal view returns(uint) {
        return (opexPrice(engineId) + teamPrice(engineId)) * (1 + vatPercentage/100);
    }
    function getPriceWithoutVat(uint engineId) internal view returns(uint) {
        return opexPrice(engineId) + teamPrice(engineId);
    }
    function getPriceWithRewards(uint engineId, bool isVatLiable) public view returns(uint) {
        if (isVatLiable) {
            return getPriceWithVat(engineId) + rewardsCost;
        } else {
            return getPriceWithoutVat(engineId) + rewardsCost;
        }
    }
    function getPriceWithoutRewards(uint engineId, bool isVatLiable) public view returns(uint) {
        if (isVatLiable) {
            return getPriceWithVat(engineId);
        } else {
            return getPriceWithoutVat(engineId);
        }
    }
    function getOpexBalanceIncrement(uint engineId, bool isVatLiable) internal view returns(uint) {
        if (isVatLiable) {
            return getPriceWithVat(engineId) - teamPrice(engineId);
        } else {
            return getPriceWithoutVat(engineId) - teamPrice(engineId);
        }
    }
    //END: UNLIMITED-SPECIFIC HELPER/COMPATIBILITY FUNCTIONS


    //BEGIN: EVENTS
    event MintWithRewards(address indexed _from, uint _tokenId, uint _engineId, string _generatorValue, string _tokenName, bool _isVatLiable, uint _amountPaid);
    event MintWithoutRewards(address indexed _from, uint _tokenId, uint _engineId, string _generatorValue, string _tokenName, bool _isVatLiable, uint _amountPaid);
    event BurnToken(address indexed _from, uint _tokenId);
    //END: EVENTS


    //BEGIN: USER FUNCTIONS

    /** 
     * @dev Minting function for when the user wants to participate in the rewards mechanism
     * @notice Mint a WOAI/Unlimited by calling this contract. Will participate in rewards. Pass the following arguments in the same order:
     * (1) Engine ID (which AI system you want to use - find the full list of supported engines from our docs)
     * (2) Generator value (the message you want to generate the NFT with)
     * (3) Token name (the name you want to associate with this NFT, appears as its name on most marketplaces)
     * (4) VAT liability status (pass true if you are VAT liable, refer to T&C for more information)
    */
    function mintWithRewards(uint _engineId, string memory _generatorValue, string memory _tokenName, bool _isVatLiable) external payable {
        require(contractActive, "Minting disabled");
        require(msg.value >= getPriceWithRewards(_engineId, _isVatLiable),"Not enough Ether");
        opexBalance += getOpexBalanceIncrement(_engineId, _isVatLiable);
        teamBalance += teamPrice(_engineId);
        //rewardsContractBalance += rewardsCost;        //Minting in this epoch adds to the balance of this epoch's rewards
        _supply.increment();
        _idCounter.increment();
        _safeMint(msg.sender, _idCounter.current());
        engineUsed[_idCounter.current()] = _engineId;
        generatorValue[_idCounter.current()] = _generatorValue;
        tokenName[_idCounter.current()] = _tokenName;
        rewardsEligibility[_idCounter.current()] = true;
        votingEligibility[_idCounter.current()] = true;
        mintTime[_idCounter.current()] = block.timestamp;
        emit MintWithRewards(msg.sender, _idCounter.current(), _engineId, _generatorValue, _tokenName, _isVatLiable, msg.value - rewardsCost);
    }

    /** 
     * @dev Minting function for when the user does not want to participate in the rewards mechanism
     * @notice Mint a WOAI/Unlimited by calling this contract. Will not participate in rewards. Pass the following arguments in the same order:
     * (1) Engine ID (which AI system you want to use - find the full list of supported engines from our docs)
     * (2) Generator value (the message you want to generate the NFT with)
     * (3) Token name (the name you want to associate with this NFT, appears as its name on most marketplaces)
     * (4) VAT liability status (pass true if you are VAT liable, refer to T&C for more information)
    */
    function mintWithoutRewards(uint _engineId, string memory _generatorValue, string memory _tokenName, bool _isVatLiable) external payable {
        require(contractActive, "Minting disabled");
        require(msg.value >= getMintPriceWithoutRewards(_engineId, _isVatLiable),"Not enough Ether");
        opexBalance += getOpexBalanceIncrement(_engineId, _isVatLiable);
        teamBalance += teamPrice(_engineId);
        _supply.increment();
        _idCounter.increment();
        _safeMint(msg.sender, _idCounter.current());
        engineUsed[_idCounter.current()] = _engineId;
        generatorValue[_idCounter.current()] = _generatorValue;
        tokenName[_idCounter.current()] = _tokenName;
        rewardsEligibility[_idCounter.current()] = false;
        votingEligibility[_idCounter.current()] = false;
        emit MintWithoutRewards(msg.sender, _idCounter.current(), _engineId, _generatorValue, _tokenName, _isVatLiable, msg.value);
    }

    /**
     * @dev Burns the NFT and decrements total supply
     * @notice Use this function to burn your NFT. Helps destroy mistakes and keep your creator portfolio clean.
     */
    function burnToken(uint _tokenId) external {
        require(msg.sender == ERC721.ownerOf(_tokenId), "Only the token owner can burn it!");
        ERC721._burn(_tokenId);
        _supply.decrement();
        emit BurnToken(msg.sender, _tokenId);
    }

    /**
     * @notice Safe way to donate to the team
    */
    function donateToTeam() external payable {
        teamBalance += msg.value;
    }
    //END: USER FUNCTIONS

}
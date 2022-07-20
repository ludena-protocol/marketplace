// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CharacterNFT is Ownable, ERC721Enumerable, Pausable, AccessControl {
    using Counters for Counters.Counter;

    // save the number of nft already owned
    mapping(address => uint256) public nftsOwned;

    mapping(address => bool) public whitelisterBuy;

    // stored whitelist
    mapping(address => bool) public whitelist;

    mapping(address => string) public groupWhitelist;

    mapping(string => uint256) private groupToQuantity;

    mapping(string => mapping(address => uint256)) private groupToPrice;

    mapping(string => uint256[2]) private groupToTime;

    mapping(string => uint256) public groupToPhase;
    // end whitelisted mapping

    // event free
    mapping(string => uint256) private freeCharacterQ;

    mapping(string => uint256[2]) private freeGroupToTime;

    mapping(string => uint256) private groupToLockUp;

    mapping(address => bool) public isClaimedFree;

    mapping(string => uint256) public freeGrouptoPhase;
    //
    
    mapping(address => bool) public acceptedToken;

    mapping(address => uint256) public tokenToPrice;

    mapping(uint256 => string) private _tokenURIs;

    mapping(uint256 => bool) public isFreeNFT;

    mapping(uint256 => uint256) public availableTime;

    // stored current packageId
    Counters.Counter private _tokenIdCount;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGERMENT_ROLE = keccak256("MANAGERMENT_ROLE");
    uint256 public limitCharacter = 25600;
    uint256 public limitCharacterFree = 10000;
    uint256 public maxBuy = 8;
    uint256 public phase = 2;
    uint256[2] public publicSaleTime;
    uint256[2] public eventTime;
    uint256[2] public presaleTime;
    address public breedingContract;

    event whitelistEvent(string groupId, address[] whitelistAddress, bool license);
    event buyCharacterEvent(address selectedToken, address sender, uint256 tokenId, uint256 phase);
    event getCharacterEvent(address buyer, uint256[] tokenIds, uint256 availableTime, uint256 phase);
    event settingEvent(string eventType, string groupId, uint256[2] price, uint256[2] duration, uint256 quantity, uint256 lockUp, uint8 phase);

    modifier isWhitelisted() {
        require(whitelist[msg.sender], "You need to be whitelisted");
        _;
    }

    modifier isBreeding(){
        require(breedingContract == msg.sender, "Only use for breeding");
        _;
    }

    constructor(address _tokenBaseAddress) ERC721("Kanimals", "KANI") {
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MANAGERMENT_ROLE, MANAGERMENT_ROLE);
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(MANAGERMENT_ROLE, _msgSender());
        acceptedToken[_tokenBaseAddress] = true;
    }
    
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    
    }

    function setBatchTokenURI(uint256[] memory tokenId_, string[] memory tokenURI_) external onlyRole(MANAGERMENT_ROLE) {
        require(tokenId_.length == tokenURI_.length, "Invalid data");
        uint256 numberOfToken = tokenId_.length;
        for(uint256 i = 0; i < numberOfToken; i++){
            _setTokenURI(tokenId_[i], tokenURI_[i]);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal virtual override
    {
        super._beforeTokenTransfer(from, to, tokenId);

        require(!isFreeNFT[tokenId] || availableTime[tokenId] < block.timestamp, "Free NFT locked");
    }

    function setPrice(address tokenAddress, uint256 _price) public onlyRole(MANAGERMENT_ROLE) {
        tokenToPrice[tokenAddress] = _price;
    }

    function setToken(address tokenAddress, bool license) public onlyRole(MANAGERMENT_ROLE) {
        acceptedToken[tokenAddress] = license;
    }

    function setLimitCharacter(uint256 _limitCharacter)
        public
        onlyRole(MANAGERMENT_ROLE)
    {
        limitCharacter = _limitCharacter;
    }

    function setMaxBuy(uint256 _max) external onlyRole(MANAGERMENT_ROLE) {
        maxBuy = _max;
    }

    function checkTimeEvent(uint256 timestamp) public view returns(bool){
        if(eventTime[0] < timestamp && timestamp < eventTime[1]){
            return false; // event
        } else if(presaleTime[0] < timestamp && timestamp < presaleTime[1]){
            return false; // presale
        } else if(publicSaleTime[0] < timestamp && timestamp < publicSaleTime[1]){
            return false; // public sale
        }
        return true;
    }

    function setTimeEvent(uint256 startTime, uint256 endTime) external onlyRole(MANAGERMENT_ROLE){
        require(checkTimeEvent(startTime), "Not available to set Start time");
        require(checkTimeEvent(endTime), "Not available to set End time");
        eventTime = [startTime, endTime];
    }

    function setTimePublicSale(uint256 startTime, uint256 endTime) external onlyRole(MANAGERMENT_ROLE){
        require(checkTimeEvent(startTime), "Not available to set Start time");
        require(checkTimeEvent(endTime), "Not available to set End time");
        publicSaleTime = [startTime, endTime];
    }

    function setTimePresale(uint256 startTime, uint256 endTime) external onlyRole(MANAGERMENT_ROLE){
        require(checkTimeEvent(startTime), "Not available to set Start time");
        require(checkTimeEvent(endTime), "Not available to set End time");
        presaleTime = [startTime, endTime];
    }

    function setPresale(string memory _group, address[2] memory tokenAddress,uint256[2] memory _price, uint256[2] memory duration, uint256 _quantity, uint8 _phase) external onlyRole(MANAGERMENT_ROLE){
        require(presaleTime[0] != 0 && presaleTime[1] != 0, "Presale time not set");
        require(duration[0] >= presaleTime[0] && duration[1] <= presaleTime[1], "Duration must in time Presale");
        groupToPrice[_group][tokenAddress[0]] = _price[0];
        groupToPrice[_group][tokenAddress[1]] = _price[1];
        groupToQuantity[_group] = _quantity;
        groupToTime[_group] = [duration[0], duration[1]];
        groupToPhase[_group] = _phase;
        emit settingEvent("presale", _group, _price, duration, _quantity, 0, _phase);
    }

    function setPublicSale(address[2] memory tokenAddress, uint256[2] memory _price, uint256[2] memory duration, uint256 _quantity, uint8 _phase) external onlyRole(MANAGERMENT_ROLE){
        require(publicSaleTime[0] != 0 && publicSaleTime[1] != 0, "Public sale time not set");
        require(duration[0] >= publicSaleTime[0] && duration[1] <= publicSaleTime[1], "Duration must in time Public sale");
        this.setPrice(tokenAddress[0], _price[0]);
        this.setPrice(tokenAddress[1], _price[1]);
        this.setMaxBuy(_quantity);
        phase = _phase;
        publicSaleTime = [duration[0], duration[1]];
        emit settingEvent("publicSale", "", _price, duration, _quantity, 0, _phase);
    }

    function setEvent(string memory _group, uint256[2] memory duration, uint256 _quantity, uint256 lockUpTime, uint8 _phase) external onlyRole(MANAGERMENT_ROLE){
        require(eventTime[0] != 0 && eventTime[1] != 0, "Event time not set");
        require(duration[0] >= eventTime[0] && duration[1] <= eventTime[1], "Duration must in time Event");
        freeCharacterQ[_group] = _quantity;
        freeGroupToTime[_group] = [duration[0], duration[1]];
        groupToLockUp[_group] = lockUpTime;
        freeGrouptoPhase[_group] = _phase;
        emit settingEvent("freeEvent", _group, [uint256(0), uint256(0)], duration, _quantity, lockUpTime, _phase);
    }

    function setWhitelist(string memory _groupId, address[] calldata _whitelist, bool _licensed)
        external
        onlyRole(MANAGERMENT_ROLE)
    {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = _licensed;
            whitelisterBuy[_whitelist[i]] = !_licensed;
            groupWhitelist[_whitelist[i]] = _groupId;
        }
        emit whitelistEvent(_groupId, _whitelist, _licensed);
    }

    function setBreedingContract(address _breeding) external onlyRole(MANAGERMENT_ROLE){
        breedingContract = _breeding;
    }

    function getSaleStatus() external view returns(uint8){
        if(eventTime[0] < block.timestamp && block.timestamp < eventTime[1]){
            return 2; // event
        } else if(presaleTime[0] < block.timestamp && block.timestamp < presaleTime[1]){
            return 1; // presale
        } else if(publicSaleTime[0] < block.timestamp && block.timestamp < publicSaleTime[1]){
            return 0; // public sale
        }
        return 3;
    }

    function getPriceByWhitelist(string memory groupId,address selectedToken) external view returns(uint256){
        return groupToPrice[groupId][selectedToken];
    }

    function getQuantityByWhitelist(string memory groupId) external view returns(uint256){
        return groupToQuantity[groupId];
    }

    function getTimeByWhitelist(string memory groupId) external view returns(uint256, uint256){
        return (groupToTime[groupId][0], groupToTime[groupId][1]);
    }

    function getQuantityByFreeGroup(string memory groupId) external view returns(uint256){
        return freeCharacterQ[groupId];
    }

    function getTimeByFreeGroup(string memory groupId) external view returns(uint256, uint256){
        return (freeGroupToTime[groupId][0], freeGroupToTime[groupId][1]);
    }

    function getLockUpByFreeGroup(string memory groupId) external view returns(uint256){
        return groupToLockUp[groupId];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Mints new NFTs (multi-item).
     * @param quantity the uri list of new tokens.
     */
    function buyCharacter(address selectedToken, uint256 quantity) external whenNotPaused{
        require(publicSaleTime[0] < block.timestamp && publicSaleTime[1] > block.timestamp, "Not in time public sale");
        require(acceptedToken[selectedToken] == true, "Unsupported token");
        require(tokenToPrice[selectedToken] > 0, "Unsupported token");
        require(quantity > 0, "quantity need bigger than 0");
        require(
            nftsOwned[msg.sender] + quantity <= maxBuy,
            "You have exceeded your minting amount"
        );
        uint256 tokenIdNow = _tokenIdCount.current();
        require(
            tokenIdNow + quantity - 1 < limitCharacter,
            "exeed limited number"
        );
        uint256 tokenPrice = tokenToPrice[selectedToken];
        IERC20(selectedToken).transferFrom(
            msg.sender,
            address(this),
            tokenPrice  * quantity
        );

        nftsOwned[msg.sender] += quantity;
        // mint one by one
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCount.current();
            _mint(msg.sender, tokenId);
            availableTime[tokenId] = block.timestamp;
            _tokenIdCount.increment();
            emit buyCharacterEvent(selectedToken,msg.sender, tokenId, phase);
        }
    }

    function whitelistBuy(address selectedToken) external isWhitelisted {
        require(groupToTime[groupWhitelist[msg.sender]][0] < block.timestamp && groupToTime[groupWhitelist[msg.sender]][1] > block.timestamp, "Not in time public sale");
        require(acceptedToken[selectedToken] == true, "Unsupported token");
        require(groupToPrice[groupWhitelist[msg.sender]][selectedToken] > 0, "Unsupported token");
        require(!whitelisterBuy[msg.sender], "Whitelist bought");
        uint256 tokenIdNow = _tokenIdCount.current();
        require(
            tokenIdNow + groupToQuantity[groupWhitelist[msg.sender]] - 1 < limitCharacter,
            "exeed limited number"
        );
        uint256 tokenPrice = groupToPrice[groupWhitelist[msg.sender]][selectedToken];
        IERC20(selectedToken).transferFrom(
            msg.sender, 
            address(this),
            tokenPrice  * groupToQuantity[groupWhitelist[msg.sender]]
        );

        // mint one by one
        for (uint256 i = 0; i < groupToQuantity[groupWhitelist[msg.sender]]; i++) {
            uint256 tokenId = _tokenIdCount.current();
            _mint(msg.sender, tokenId);
            availableTime[tokenId] = block.timestamp;
            _tokenIdCount.increment();
            emit buyCharacterEvent(selectedToken,msg.sender, tokenId, groupToPhase[groupWhitelist[msg.sender]]);
        }
        whitelisterBuy[msg.sender] = true;
    }

    function getFreeCharacter() external isWhitelisted{
        require(freeGroupToTime[groupWhitelist[msg.sender]][0] < block.timestamp && freeGroupToTime[groupWhitelist[msg.sender]][1] > block.timestamp, "Not in time event");
        require(!isClaimedFree[msg.sender], "User claimed");
        uint256 tokenIdNow = _tokenIdCount.current();
        uint256 availTime = block.timestamp + groupToLockUp[groupWhitelist[msg.sender]];
        require(
            tokenIdNow + freeCharacterQ[groupWhitelist[msg.sender]] - 1 < limitCharacterFree,
            "exeed limited number"
        );
        uint256[] memory listToken = new uint256[](freeCharacterQ[groupWhitelist[msg.sender]]);
        isClaimedFree[msg.sender] = true;
        // mint one by one
        for (uint256 i = 0; i < freeCharacterQ[groupWhitelist[msg.sender]]; i++) {
            uint256 tokenId = _tokenIdCount.current();
            _mint(msg.sender, tokenId);
            availableTime[tokenId] = availTime;
            isFreeNFT[tokenId] = true;
            listToken[i] = tokenId;
            _tokenIdCount.increment();
        }
        emit getCharacterEvent(msg.sender, listToken, availTime, freeGrouptoPhase[groupWhitelist[msg.sender]]);
    }

    function breedNFT(uint256 matronId, uint256 sireId, address _receiver, uint256 breedWaitingTime) external isBreeding returns (uint256 tokenID){
        uint256 tokenIdNow = _tokenIdCount.current();
        require(!isFreeNFT[matronId] || block.timestamp >= availableTime[matronId], "Matron not available to breed");
        require(!isFreeNFT[sireId] || block.timestamp >= availableTime[sireId], "Sire not available to breed");
        require(
            tokenIdNow + 1 < limitCharacter,
            "exeed limited number"
        );
        uint256 tokenId = _tokenIdCount.current();
        _mint(_receiver, tokenId);
        availableTime[tokenId] = block.timestamp + breedWaitingTime;
        _tokenIdCount.increment();
        nftsOwned[msg.sender] += 1;
        return tokenId;
    }

    /**
     * withdraw all erc20 token base balance of this contract
     */
    function withdrawToken(address tokenAddress) external onlyRole(ADMIN_ROLE) {
        require(acceptedToken[tokenAddress] == true, "Unsupported token");
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(msg.sender, balance);
    }

    /**
     * get erc20 token base balance of this contract
     */
    function getContractERC20Balance(address tokenAddress) public onlyOwner view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }
}


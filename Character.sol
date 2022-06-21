// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CharacterNFT is Ownable, ERC721Enumerable, AccessControl, Pausable {
    using Counters for Counters.Counter;

    // save the number of nft already owned
    mapping(address => uint256) public nftsOwned;

    // stored whitelist
    mapping(address => bool) public whitelist;

    mapping(address => bool) public acceptedToken;

    mapping(address => uint256) public tokenToPrice;

    mapping(uint256 => uint256) public avaiableTime;

    mapping(uint256 => string) private _tokenURIs;

    // stored current packageId
    Counters.Counter private _tokenIdCount;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGERMENT_ROLE = keccak256("MANAGERMENT_ROLE");
    uint256 public limitCharacter = 12800;
    uint256 public maxBuy = 8;
    address public breedingContract;
    bool public isPresale = false; //false for allow everyone buy nft, true for whitelist

    event buyCharacterEvent(address selectedToken, address sender, uint256 tokenId);

    modifier isWhitelisted() {
        if (isPresale == true) {
            require(whitelist[msg.sender], "You need to be whitelisted");
        }
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

    function pause() public onlyRole(MANAGERMENT_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(MANAGERMENT_ROLE) {
        _unpause();
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

    function setBatchTokenURI(uint256[] memory tokenId_, string[] memory tokenURI_) external onlyOwner {
        require(tokenId_.length == tokenURI_.length, "Invalid data");
        uint256 numberOfToken = tokenId_.length;
        for(uint256 i = 0; i < numberOfToken; i++){
            _setTokenURI(tokenId_[i], tokenURI_[i]);
        }
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

    function setPresale(bool _value) external onlyRole(MANAGERMENT_ROLE) {
        isPresale = _value;
    }

    function setMaxBuy(uint256 _max) external onlyRole(MANAGERMENT_ROLE) {
        maxBuy = _max;
    }

    function setWhitelist(address[] calldata _whitelist, bool _licensed)
        external
        onlyRole(MANAGERMENT_ROLE)
    {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = _licensed;
        }
    }

    function setBreedingContract(address _breeding) external onlyRole(MANAGERMENT_ROLE){
        breedingContract = _breeding;
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
    function buyCharacter(address selectedToken,uint256 quantity) external whenNotPaused isWhitelisted {
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
            avaiableTime[tokenId] = block.timestamp;
            _tokenIdCount.increment();
            emit buyCharacterEvent(selectedToken,msg.sender, tokenId);
        }
    }

    function breedNFT(address _receiver, uint256 breedWaitingTime) external isBreeding whenNotPaused returns (uint256 tokenID){
        uint256 tokenIdNow = _tokenIdCount.current();
        require(
            tokenIdNow + 1 < limitCharacter,
            "exeed limited number"
        );
        uint256 tokenId = _tokenIdCount.current();
        _mint(_receiver, tokenId);
        avaiableTime[tokenId] = block.timestamp + breedWaitingTime;
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

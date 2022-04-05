// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

contract COKSNFT is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    Ownable,
    ERC721Burnable,
    Multicall,
    AccessControl
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    string public baseURI;
    mapping(uint256 => uint256) public nftAttribute;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => bool) public userBlacklist;

    constructor() ERC721("COKS NFT", "COKSNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    modifier validAddress(address addr) {
        require(addr != address(0x0));
        _;
    }

    modifier onlyRoleMint() {
        if (_msgSender() == owner()) {
            _;
        }

        _checkRole(MINTER_ROLE, _msgSender());

        _;
    }

    function pause() public onlyRole(MINTER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(MINTER_ROLE) {
        _unpause();
    }

    function setRoleMinter(address _user) external onlyOwner {
        _setupRole(MINTER_ROLE, _user);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newURI) external onlyOwner {
        baseURI = _newURI;
    }

    function safeMint(address to, uint256 attribute) public onlyRoleMint {
        uint256 tokenId = _tokenIdCounter.current();
        nftAttribute[tokenId] = attribute;
        _tokenIdCounter.increment();

        _safeMint(to, tokenId);
    }

    function safeMintMulti(
        address _to,
        uint256 _num,
        uint256[] memory _listAttr
    ) public onlyRoleMint {
        for (uint64 i = 0; i < _num; i++) {
            safeMint(_to, _listAttr[i]);
        }
    }

    function addUserBlacklist(address _newAddress)
        external
        onlyOwner
        validAddress(_newAddress)
    {
        require(
            userBlacklist[_newAddress] != true,
            "This address already in list!"
        );

        userBlacklist[_newAddress] = true;
    }

    function removeUserBlacklist(address _newAddress)
        external
        onlyOwner
        validAddress(_newAddress)
    {
        require(userBlacklist[_newAddress] == true, "This address clean!");
        userBlacklist[_newAddress] = false;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        require(
            userBlacklist[from] != true,
            "You in blacklist, please DM admin for support!!"
        );
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

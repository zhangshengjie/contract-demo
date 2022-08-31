// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFT is ERC721ABurnable, AccessControl {
    bytes32 public constant SALE_ROLE = keccak256("SALE_ROLE");
    bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");

    using ECDSA for bytes32;

    event PriceChanged(uint256 price);

    event SpecificSaleChanged(
        address user,
        uint32 maxSupply,
        uint256 salePrice
    );

    event SyntheticMinted(uint256[] burnedToken, uint256 newTokenId);

    string private baseURI;
    uint32 public maxSupply;

    bool public saleEnabled;
    bool private defaultSale;
    uint256 private salePrice;

    address paymentReceiver;

    struct specificSale {
        uint32 maxSupply;
        uint32 claimed;
        uint256 salePrice;
    }

    mapping(address => specificSale) private specificSales;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint32 maxSupply_,
        address paymentReceiver_,
        address controller_
    ) ERC721A(name_, symbol_) {
        baseURI = baseURI_;
        maxSupply = maxSupply_;
        paymentReceiver = paymentReceiver_;

        _grantRole(DEFAULT_ADMIN_ROLE, controller_);
        _grantRole(SALE_ROLE, controller_);
        _grantRole(SIGN_ROLE, controller_);
    }

    function updateBaseURI(string memory baseURI_)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseURI = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    modifier forSale() {
        require(saleEnabled, "Sale not enabled");
        _;
    }

    /**
     * @dev Get address who recieves payment from mints
     */
    function getPaymentReceiver() external view returns (address) {
        return paymentReceiver;
    }

    /**
     * @dev Set address who recieves payment from mints
     */
    function setPaymentReceiver(address account_)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(account_ != address(0), "Cannot set zero address");
        paymentReceiver = account_;
    }

    /**
     * @dev Batch mint to owner
     */
    function reserveGiveaway(uint256 amount_)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(amount_ > 0, "Cannot mint zero");
        require(maxSupply >= totalSupply() + amount_, "Insufficent supply");
        _safeMint(msg.sender, amount_);
    }

    /**
     * @dev Toggle to allow for minting NFTs
     */
    function toggleSaleEnable(bool state_) public onlyRole(SALE_ROLE) {
        require(saleEnabled != state_, "state already set");
        saleEnabled = state_;
    }

    /**
     * @dev get specific sale info
     */
    function getSpecificSale(address user_)
        public
        view
        returns (specificSale memory)
    {
        return specificSales[user_];
    }

    /**
     * @dev set specific sale
     */
    function setSpecificSale(
        address user_,
        uint32 maxSupply_,
        uint256 salePrice_
    ) public onlyRole(SALE_ROLE) {
        specificSale storage specificSale_ = specificSales[user_];
        require(
            maxSupply_ >= specificSale_.claimed,
            "Cannot set max supply less than claimed"
        );
        specificSale_.maxSupply = maxSupply_;
        specificSale_.salePrice = salePrice_;
        emit SpecificSaleChanged(user_, maxSupply_, salePrice_);
    }

    /**
     * @dev Set the base price of NFTs for sale
     */
    function setSalePrice(uint256 salePrice_) public onlyRole(SALE_ROLE) {
        require(salePrice_ > 0, "Cannot set zero price");
        salePrice = salePrice_;
        emit PriceChanged(salePrice);
    }

    /**
     * @dev Check if default sale is enabled
     */
    function isDefaultPrice() public view returns (bool) {
        return defaultSale;
    }

    /**
     * @dev Get price if price controller is disabled
     */
    function getDefaultPrice(uint256 amount_) public view returns (uint256) {
        require(amount_ > 0, "Cannot mint zero");
        require(salePrice > 0, "Sale price not set");
        return amount_ * salePrice;
    }

    /**
     * @dev Admin set default sale state
     */
    function setDefaultSale(bool defaultSale_) public onlyRole(SALE_ROLE) {
        require(
            defaultSale_ != defaultSale,
            "defaultSale already has that value"
        );
        defaultSale = defaultSale_;
    }

    /**
     * @dev Get price from specificSales, and then save NFT voucher and user states
     *
     * @return value in wei for user user_ to buy amount_ of NFTs
     */
    function getPrice(address user_, uint32 amount_)
        internal
        returns (uint256)
    {
        require(amount_ > 0, "Cannot mint zero");
        specificSale storage specificSale_ = specificSales[user_];
        require(
            amount_ >= (specificSale_.maxSupply - specificSale_.claimed),
            "Insufficent supply"
        );
        uint256 price = specificSale_.salePrice * amount_;
        specificSale_.claimed += amount_;
        return price;
    }

    /**
     * @dev Batch mint consecutive NFTs to a the soender wallet
     * Compiles the price of NFTs to be minted using the price controller contract.
     * Then saves the number of vouchers claimed by the user and the used NFT voucher.
     */
    function batchMint(uint32 amount_) external payable forSale {
        require(amount_ > 0, "Cannot mint zero");
        require(maxSupply >= totalSupply() + amount_, "Insufficent supply");
        uint256 price = defaultSale
            ? getDefaultPrice(amount_)
            : getPrice(msg.sender, amount_);
        require(msg.value >= price, "Insufficent input amount");
        _safeMint(msg.sender, amount_);
    }

    function SyntheticMint(
        uint256[] calldata ids,
        address signer,
        bytes memory signature
    ) external {
        _checkRole(SIGN_ROLE, signer);
        require(
            ids.length > 1 && ids.length < type(uint32).max,
            "Cannot synthetically mint less than 2 NFTs"
        );
        bytes32 hash = keccak256(abi.encodePacked(ids, address(this))); // add address(this) to prevent replay attacks
        require(hash.recover(signature) == signer, "Invalid signature");

        for (uint256 i = 0; i < ids.length; ) {
            burn(ids[i]);
            unchecked {
                i++;
            }
        }
        unchecked {
            maxSupply = maxSupply - uint32(ids.length) + 1;
        }
        uint256 nextTokenID = _nextTokenId();
        _safeMint(signer, 1);
        emit SyntheticMinted(ids, nextTokenID);
    }

    /**
     * @dev Admin withdraw function
     */
    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        Address.sendValue(payable(paymentReceiver), balance);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721A)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

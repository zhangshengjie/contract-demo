// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./AccessControl.sol";

contract NFT is ERC721A, ERC721ABurnable, AccessControl {
    uint8 public constant SALE_ROLE = 1;
    uint8 public constant SIGN_ROLE = 2;
    uint8 public constant MINT_ROLE = 3;

    using ECDSA for bytes32;

    event PriceChanged(uint256 price);

    event SyntheticMinted(uint256[] burnedToken, uint256 mintedToken);

    string private baseURI;
    uint32 public maxSupply;

    uint64 public saleStartTime;
    uint256 private salePrice;

    address paymentReceiver;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint32 maxSupply_,
        address paymentReceiver_,
        address controller_,
        address saleRole_,
        address signRole_
    ) ERC721A(name_, symbol_) {
        baseURI = baseURI_;
        maxSupply = maxSupply_;
        paymentReceiver = paymentReceiver_;

        _setRole(ADMIN_ROLE, controller_);
        _setRole(MINT_ROLE, controller_);
        _setRole(SALE_ROLE, saleRole_);
        _setRole(SIGN_ROLE, signRole_);
    }

    function updateBaseURI(string memory baseURI_) public onlyRole(ADMIN_ROLE) {
        baseURI = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    modifier forSale() {
        require(
            saleStartTime > 0 && saleStartTime <= block.timestamp,
            "Sale not enabled"
        );
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
    function setPaymentReceiver(address account_) public onlyRole(ADMIN_ROLE) {
        require(account_ != address(0), "Cannot set zero address");
        paymentReceiver = account_;
    }

    /**
     * @dev Toggle to allow for minting NFTs
     */
    function setSaleStartTime(uint64 saleStartTime_)
        public
        onlyRole(SALE_ROLE)
    {
        saleStartTime = saleStartTime_;
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
     * @dev Get price
     */
    function getPrice(uint256 amount_) public view returns (uint256) {
        require(salePrice > 0, "Sale price not set");
        return amount_ * salePrice;
    }

    /**
     * @dev Batch mint consecutive NFTs to a the soender wallet
     */
    function batchMint(uint32 amount_) external payable forSale {
        require(amount_ > 0, "Cannot mint zero");
        require(maxSupply >= totalSupply() + amount_, "Insufficent supply");
        uint256 price = getPrice(amount_);
        require(msg.value >= price, "Insufficent input amount");
        _safeMint(msg.sender, amount_);
    }

    /**
     * @dev Mint NFT using signed message
     *
     */
    function signedBatchMint(uint32 amount_, bytes memory signature_)
        external
        payable
        forSale
    {
        require(amount_ > 0, "Cannot mint zero");
        require(maxSupply >= totalSupply() + amount_, "Insufficent supply");

        bytes32 hash = keccak256(
            abi.encodePacked(msg.sender, msg.value, amount_)
        );
        _checkRole(
            MINT_ROLE,
            hash.toEthSignedMessageHash().recover(signature_)
        );

        _safeMint(msg.sender, amount_);
    }

    /**
     * @dev Synthesized through NFTs
     */
    function SyntheticMint(uint256[] calldata ids_, bytes memory signature_)
        external
    {
        require(
            ids_.length > 1 && ids_.length < type(uint32).max,
            "Cannot synthetically mint less than 2 NFTs"
        );
        bytes32 hash = keccak256(abi.encodePacked(ids_, address(this))); // add address(this) to prevent replay attacks
        _checkRole(
            SIGN_ROLE,
            hash.toEthSignedMessageHash().recover(signature_)
        );

        for (uint256 i = 0; i < ids_.length; ) {
            burn(ids_[i]);
            unchecked {
                i++;
            }
        }
        unchecked {
            maxSupply = maxSupply - uint32(ids_.length) + 1;
        }
        uint256 nextTokenID = _nextTokenId();
        _safeMint(msg.sender, 1);
        emit SyntheticMinted(ids_, nextTokenID);
    }

    /**
     * @dev Admin withdraw function
     */
    function withdraw() public onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        Address.sendValue(payable(paymentReceiver), balance);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A)
        returns (bool)
    {
        /**
             0x01ffc9a7  ERC165 interface ID for ERC165.
             0x80ac58cd ERC165 interface ID for ERC721.
             0x5b5e139f ERC165 interface ID for ERC721Metadata.
         */
        return ERC721A.supportsInterface(interfaceId);
    }
}

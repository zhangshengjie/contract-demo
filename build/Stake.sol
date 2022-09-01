// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;



// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)
/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// source: OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


interface IERC721 {
    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);
}

contract Stake is Ownable {
    event MinimumStakeTimeChanged(uint24 newMinimumStakeTime);
    event StakeCreated(
        uint256 indexed stakeId,
        address staker,
        address NFT,
        uint256[] tokenIds
    );
    event StakeWithdrawn(uint256 indexed stakeId);

    uint24 public minimumStakeTime = 7 days; // uint24 max value is 0.5 years
    uint256 public stakeIndex = 0;

    struct StakeInfo {
        address staker;
        address NFT;
        uint256[] tokenIds;
        uint64 unlockTime; // uint64 for full timestamp
    }

    mapping(uint256 => StakeInfo) private stakes;

    constructor(address owner_) Ownable(owner_) {}

    /**
     * @dev update the minimum stake time
     * @param newMinimumStakeTime new minimum stake time max value is 0.5 years
     *
     * Emits a {MinimumStakeTimeUpdated} event.
     */
    function setMinimumStakeTime(uint24 newMinimumStakeTime) public onlyOwner {
        require(newMinimumStakeTime > 0);
        require(newMinimumStakeTime != minimumStakeTime);

        minimumStakeTime = newMinimumStakeTime;
        emit MinimumStakeTimeChanged(minimumStakeTime);
    }

    /**
     * @dev create a new stake
     * @param NFT NFT address
     * @param tokenIds tokenIds of the NFT
     *
     * Emits a {StakeCreated} event.
     */
    function createStake(address NFT, uint256[] calldata tokenIds) public {
        require(tokenIds.length > 0, "Stake: No tokens provided");
        address sender = _msgSender();
        require(
            IERC721(NFT).isApprovedForAll(sender, address(this)),
            "Stake: Not approved for all"
        );
        for (uint256 i = 0; i < tokenIds.length; ) {
            IERC721(NFT).transferFrom(sender, address(this), tokenIds[i]);
            unchecked {
                i++;
            }
        }
        unchecked {
            uint64 unlockTime = uint64(block.timestamp) + minimumStakeTime;
            stakes[stakeIndex] = StakeInfo(sender, NFT, tokenIds, unlockTime);
            emit StakeCreated(stakeIndex, sender, NFT, tokenIds);
            stakeIndex++;
        }
    }

    /**
     * @dev get the stake info
     */
    function stakeInfo(uint256 stakeId) public view returns (StakeInfo memory) {
        require(stakes[stakeId].staker != address(0), "Stake: Stake not found");
        return stakes[stakeId];
    }

    /**
     * @dev withdraw a stake
     * @param stakeId stake id
     *
     * Emits a {StakeWithdrawn} event.
     */
    function withdrawStake(uint256 stakeId) public {
        StakeInfo memory stake = stakes[stakeId];
        require(stake.staker == _msgSender(), "Stake: Not staker");
        unchecked {
            require(
                stake.unlockTime >= block.timestamp,
                "Stake: Not enough time has passed"
            );
        }
        for (uint256 i = 0; i < stake.tokenIds.length; ) {
            IERC721(stake.NFT).transferFrom(
                address(this),
                stake.staker,
                stake.tokenIds[i]
            );
            unchecked {
                i++;
            }
        }
        emit StakeWithdrawn(stakeId);
        delete stakes[stakeId]; // recycle gas
    }
}
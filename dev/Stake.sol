// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";

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

interface IERC20 {
    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract Stake is Ownable {
    // fired when NFT minimum stake time changes
    event NFTMinimumStakeTimeChanged(uint24 newMinimumStakeTime);

    // fired when FT minimum stake time changes
    event FTMinimumStakeTimeChanged(uint24 newMinimumStakeTime);

    // fired when FT minimum stake amount changes
    event FTMinimumStakeAmountChanged(uint256 newMinimumStakeAmount);

    // fired when NFT stake created
    event NFTStakeCreated(
        uint256 indexed stakeId,
        address staker,
        address asset,
        uint256[] tokenIds
    );

    // fired when FT stake created
    event FTStakeCreated(
        uint256 indexed stakeId,
        address staker,
        address asset,
        uint256 amount
    );

    // fired when NFT stake cancelled
    event NFTStakeWithdrawn(uint256 indexed stakeId);

    // fired when FT stake cancelled
    event FTStakeWithdrawn(uint256 indexed stakeId);

    // NFT minimum stake time
    uint24 public NFTMinimumStakeTime = 7 days; // uint24 max value is 0.5 years

    // FT minimum stake time
    uint24 public FTMinimumStakeTime = 7 days; // uint24 max value is 0.5 years

    // FT minimum stake amount
    uint256 public FTMinimumStakeAmount = 1 ether;

    // NFT stake index
    uint256 public stakeIndex = 0;

    // NFT stake info
    struct NFTStakeInfo {
        address staker; // staker address
        address asset; // ERC721 token address
        uint256[] tokenIds; // token ids
        uint64 unlockTime; // uint64 for full timestamp
    }

    // FT stake info
    struct FTStakeInfo {
        address staker; // staker address
        address asset; // ERC20 token address
        uint256 amount; // amount
        uint64 unlockTime; // uint64 for full timestamp
    }

    // NFT stakes map
    mapping(uint256 => NFTStakeInfo) private NFTStake;

    // FT stakes map
    mapping(uint256 => FTStakeInfo) private FTStake;

    constructor(address owner_) Ownable(owner_) {}

    /**
     * @dev update the minimum stake time
     * @param newNFTMinimumStakeTime new minimum stake time max value is 0.5 years
     *
     * Emits a {MinimumStakeTimeUpdated} event.
     */
    function setNFTMinimumStakeTime(uint24 newNFTMinimumStakeTime)
        public
        onlyOwner
    {
        require(newNFTMinimumStakeTime > 0);
        require(newNFTMinimumStakeTime != NFTMinimumStakeTime);

        NFTMinimumStakeTime = newNFTMinimumStakeTime;
        emit NFTMinimumStakeTimeChanged(NFTMinimumStakeTime);
    }

    /**
     * @dev update the minimum stake time
     * @param newFTMinimumStakeTime new minimum stake time max value is 0.5 years
     *
     * Emits a {MinimumStakeTimeUpdated} event.
     */
    function setFTMinimumStakeTime(uint24 newFTMinimumStakeTime)
        public
        onlyOwner
    {
        require(newFTMinimumStakeTime > 0);
        require(newFTMinimumStakeTime != FTMinimumStakeTime);

        FTMinimumStakeTime = newFTMinimumStakeTime;
        emit FTMinimumStakeTimeChanged(FTMinimumStakeTime);
    }

    /**
     * @dev update the minimum stake amount
     * @param newFTMinimumStakeAmount new minimum stake amount
     *
     * Emits a {FTMinimumStakeAmountChanged} event.
     */
    function setFTMinimumStakeAmount(uint24 newFTMinimumStakeAmount)
        public
        onlyOwner
    {
        require(newFTMinimumStakeAmount > 0);
        require(newFTMinimumStakeAmount != FTMinimumStakeAmount);

        FTMinimumStakeAmount = newFTMinimumStakeAmount;
        emit FTMinimumStakeAmountChanged(FTMinimumStakeAmount);
    }

    /**
     * @dev create a new NFT stake
     * @param asset NFT address
     * @param tokenIds tokenIds of the NFT
     *
     * Emits a {NFTStakeCreated} event.
     */
    function createNFTStake(address asset, uint256[] calldata tokenIds) public {
        require(tokenIds.length > 0, "Stake: No tokens provided");
        address sender = msg.sender;
        IERC721 ERC721 = IERC721(asset);
        require(
            ERC721.isApprovedForAll(sender, address(this)),
            "Stake: Not approved for all"
        );
        for (uint256 i = 0; i < tokenIds.length; ) {
            ERC721.transferFrom(sender, address(this), tokenIds[i]);
            unchecked {
                i++;
            }
        }
        unchecked {
            uint64 unlockTime = uint64(block.timestamp) + NFTMinimumStakeTime;
            NFTStake[stakeIndex] = NFTStakeInfo(
                sender,
                asset,
                tokenIds,
                unlockTime
            );
            stakeIndex++;
        }
        emit NFTStakeCreated(stakeIndex, sender, asset, tokenIds);
    }

    /**
     * @dev create a new FT stake
     * @param asset NFT address
     * @param amount amount of the ERC20
     *
     * Emits a {FTStakeCreated} event.
     */
    function createFTStake(address asset, uint256 amount) public {
        require(amount > FTMinimumStakeAmount, "Stake: Amount too low");
        address sender = msg.sender;
        IERC20 ERC20 = IERC20(asset);
        require(
            ERC20.allowance(sender, address(this)) >= amount,
            "Stake: Not enough allowance"
        );
        ERC20.transferFrom(sender, address(this), amount);
        unchecked {
            uint64 unlockTime = uint64(block.timestamp) + FTMinimumStakeTime;
            FTStake[stakeIndex] = FTStakeInfo(
                sender,
                asset,
                amount,
                unlockTime
            );
            stakeIndex++;
        }
        emit FTStakeCreated(stakeIndex, sender, asset, amount);
    }

    /**
     * @dev get the NFT stake info
     */
    function getNFTStakeInfo(uint256 stakeId)
        public
        view
        returns (NFTStakeInfo memory)
    {
        require(
            NFTStake[stakeId].staker != address(0),
            "Stake: Stake not found"
        );
        return NFTStake[stakeId];
    }

    /**
     * @dev get the FT stake info
     */
    function getFTStakeInfo(uint256 stakeId)
        public
        view
        returns (FTStakeInfo memory)
    {
        require(
            FTStake[stakeId].staker != address(0),
            "Stake: Stake not found"
        );
        return FTStake[stakeId];
    }

    /**
     * @dev withdraw a NFT stake
     * @param stakeId stake id
     *
     * Emits a {NFTStakeWithdrawn} event.
     */
    function withdrawNFTStake(uint256 stakeId) public {
        NFTStakeInfo memory stake = NFTStake[stakeId];
        require(stake.staker == msg.sender, "Stake: Not staker");
        require(
            stake.unlockTime < block.timestamp,
            "Stake: Not enough time has passed"
        );

        for (uint256 i = 0; i < stake.tokenIds.length; ) {
            IERC721(stake.asset).transferFrom(
                address(this),
                stake.staker,
                stake.tokenIds[i]
            );
            unchecked {
                i++;
            }
        }
        emit NFTStakeWithdrawn(stakeId);
        delete NFTStake[stakeId]; // recycle gas
    }

    /**
     * @dev withdraw a FT stake
     * @param stakeId stake id
     *
     * Emits a {FTStakeWithdrawn} event.
     */
    function withdrawFTStake(uint256 stakeId) public {
        FTStakeInfo memory stake = FTStake[stakeId];
        require(stake.staker == msg.sender, "Stake: Not staker");
        require(
            stake.unlockTime < block.timestamp,
            "Stake: Not enough time has passed"
        );
        IERC20(stake.asset).transferFrom(
            address(this),
            stake.staker,
            stake.amount
        );

        emit FTStakeWithdrawn(stakeId);
        delete FTStake[stakeId]; // recycle gas
    }
}

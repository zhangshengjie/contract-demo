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
        address sender = msg.sender;
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
        require(stake.staker == msg.sender, "Stake: Not staker");
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

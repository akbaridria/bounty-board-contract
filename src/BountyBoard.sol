// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBountyBoard.sol";

import "./Types.sol";

contract BountyBoard is Ownable {
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 5;
    uint256 bountyIdCounter;

    mapping(uint256 => Bounty) public bounties;
    mapping(address => uint256[]) public userBounties;

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Creates a new bounty
     * @param _cid The CID of the bounty
     * @param _prize The total prize amount for the bounty
     * @param _deadline The deadline for submissions
     * @param _resultDeadline The deadline for announcing results
     * @param _minParticipants Minimum number of participants required
     * @param _totalWinners Total number of winners to be selected
     * @param _prizes Array of individual prize amounts for each winner
     * @param _bountyType Type of the bounty (editable or non-editable)
     */
    function createBounty(
        string memory _cid,
        uint256 _prize,
        uint256 _deadline,
        uint256 _resultDeadline,
        uint16 _minParticipants,
        uint16 _totalWinners,
        uint256[] memory _prizes,
        BountyType _bountyType
    ) external payable {
        require(_prize > 0, "BountyBoard: ZERO_PRIZE");
        require(_deadline > block.timestamp, "BountyBoard: PAST_DEADLINE");
        require(_resultDeadline > _deadline, "BountyBoard: INVALID_RESULT_DEADLINE");
        require(_minParticipants > 0, "BountyBoard: ZERO_PARTICIPANTS");
        require(_totalWinners > 0, "BountyBoard: ZERO_WINNERS");
        require(_prizes.length == _totalWinners, "BountyBoard: PRIZES_WINNERS_MISMATCH");

        _checkPrieAndFee(_prizes);

        Bounty memory newBounty = Bounty({
            id: bountyIdCounter,
            isActive: true,
            creator: msg.sender,
            cid: _cid,
            deadline: _deadline,
            resultDeadline: _resultDeadline,
            minParticipants: _minParticipants,
            totalWinners: _totalWinners,
            prizes: _prizes,
            selectedWinners: new address[](0),
            status: BountyStatus.OPEN,
            bountyType: _bountyType
        });

        bounties[bountyIdCounter] = newBounty;
        userBounties[msg.sender].push(bountyIdCounter);

        emit BountyCreated(
            bountyIdCounter,
            msg.sender,
            _cid,
            _deadline,
            _resultDeadline,
            _minParticipants,
            _totalWinners,
            _prizes,
            _bountyType
        );

        bountyIdCounter++;
    }

    /**
     * @dev Calculates the total prize amount and platform fee
     * @param _prizes Array of individual prize amounts
     * @return totalPrizeAmount The sum of all prizes
     * @return platformFee The fee collected by the platform
     */
    function calculatePrizesAndFee(uint256[] memory _prizes)
        public
        pure
        returns (uint256 totalPrizeAmount, uint256 platformFee)
    {
        totalPrizeAmount = 0;

        for (uint256 i = 0; i < _prizes.length; i++) {
            totalPrizeAmount += _prizes[i];
        }

        platformFee = _calculatePlatformFee(totalPrizeAmount);

        return (totalPrizeAmount, platformFee);
    }

    /**
     * @dev Calculates the platform fee based on the total amount
     * @param _amount The total amount to calculate the fee from
     * @return The calculated platform fee
     */
    function _calculatePlatformFee(uint256 _amount) internal pure returns (uint256) {
        return (_amount * PLATFORM_FEE_PERCENTAGE) / 100;
    }

    /**
     * @dev Checks if the user has sent enough funds to cover the total prize amount and platform fee
     * @param _prizes Array of individual prize amounts
     */
    function _checkPrieAndFee(uint256[] memory _prizes) internal {
        (uint256 totalPrizeAmount, uint256 platformFee) = calculatePrizesAndFee(_prizes);
        if (msg.value < totalPrizeAmount + platformFee) {
            revert BountyBoard__InsufficientFunds(msg.value, totalPrizeAmount + platformFee);
        }
    }

    /**
     * @dev Edits an existing bounty
     * @param _bountyId The ID of the bounty to edit
     * @param _cid The new CID of the bounty
     * @param _deadline The new deadline for submissions
     * @param _resultDeadline The new deadline for announcing results
     * @param _minParticipants Minimum number of participants required
     * @param _totalWinners Total number of winners to be selected
     * @param _prizes Array of individual prize amounts for each winner
     */
    function editBounty(
        uint256 _bountyId,
        string memory _cid,
        uint256 _deadline,
        uint256 _resultDeadline,
        uint16 _minParticipants,
        uint16 _totalWinners,
        uint256[] memory _prizes
    ) external payable {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.isActive, "BountyBoard: BOUNTY_NOT_FOUND");
        require(bounty.creator == msg.sender, "BountyBoard: NOT_CREATOR");

        bounty.cid = _cid;
        bounty.deadline = _deadline;
        bounty.resultDeadline = _resultDeadline;
        bounty.minParticipants = _minParticipants;
        bounty.totalWinners = _totalWinners;
        bounty.prizes = _prizes;

        _checkPrieAndFee(_prizes);

        emit BountyCreated(
            bounty.id,
            msg.sender,
            _cid,
            _deadline,
            _resultDeadline,
            _minParticipants,
            _totalWinners,
            _prizes,
            bounty.bountyType
        );
    }

    receive() external payable {}
    fallback() external payable {}
}

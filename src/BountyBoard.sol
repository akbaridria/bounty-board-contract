// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IBountyBoard.sol";

import "./Types.sol";

contract BountyBoard is IBountyBoard, Ownable, ReentrancyGuard {
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 5;
    uint256 public bountyIdCounter;

    mapping(uint256 => Bounty) public bounties;
    mapping(address => uint256[]) public userBounties;
    mapping(uint256 => Submission[]) public bountySubmissions;
    mapping(uint256 => mapping(address => bool)) public isParticipant;

    uint256 public feeCollected;

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Creates a new bounty
     * @param _cid The CID of the bounty
     * @param _deadline The deadline for submissions
     * @param _resultDeadline The deadline for announcing results
     * @param _minParticipants Minimum number of participants required
     * @param _totalWinners Total number of winners to be selected
     * @param _prizes Array of individual prize amounts for each winner
     * @param _bountyType Type of the bounty (editable or non-editable)
     */
    function createBounty(
        string memory _cid,
        uint256 _deadline,
        uint256 _resultDeadline,
        uint16 _minParticipants,
        uint16 _totalWinners,
        uint256[] memory _prizes,
        BountyType _bountyType
    ) external payable override nonReentrant returns (uint256) {
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

        return bountyIdCounter - 1;
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
        feeCollected += platformFee;
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
    ) external payable override nonReentrant {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.isActive, "BountyBoard: BOUNTY_NOT_FOUND");
        require(bounty.creator == msg.sender, "BountyBoard: NOT_CREATOR");
        require(bounty.bountyType == BountyType.EDITABLE, "BountyBoard: NON_EDITABLE_BOUNTY");

        bounty.cid = _cid;
        bounty.deadline = _deadline;
        bounty.resultDeadline = _resultDeadline;
        bounty.minParticipants = _minParticipants;
        bounty.totalWinners = _totalWinners;
        bounty.prizes = _prizes;

        _checkPrieAndFee(_prizes);

        emit BountyUpdated(
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

    /**
     * @dev Allows the creator to select winners for the bounty and distribute prizes
     * @param _bountyId The ID of the bounty
     * @param _winners Array of addresses of the selected winners
     */
    function selectWinners(uint256 _bountyId, address[] calldata _winners) external override {
        Bounty storage bounty = bounties[_bountyId];

        require(bounty.isActive, "BountyBoard: BOUNTY_NOT_FOUND");
        require(bounty.creator == msg.sender, "BountyBoard: NOT_CREATOR");
        require(_winners.length == bounty.totalWinners, "BountyBoard: WINNERS_MISMATCH");
        require(bounty.selectedWinners.length == 0, "BountyBoard: WINNERS_ALREADY_SELECTED");
        require(bounty.minParticipants <= _winners.length, "BountyBoard: NOT_ENOUGH_PARTICIPANTS");
        require(block.timestamp <= bounty.resultDeadline, "BountyBoard: RESULT_DEADLINE_PASSED");
        require(block.timestamp >= bounty.deadline, "BountyBoard: SUBMISSION_DEADLINE_NOT_REACHED");

        _validateWinners(_winners, bounty.creator);

        _verifyParticipants(_bountyId, _winners);

        _distributePrizes(_winners, bounty.prizes);

        bounty.selectedWinners = _winners;
        bounty.isActive = false;
        emit WinnersSelected(_bountyId, _winners);
    }

    /**
     * @dev Internal function to validate winner addresses
     */
    function _validateWinners(address[] calldata _winners, address _creator) internal pure {
        for (uint256 i = 0; i < _winners.length; i++) {
            require(_winners[i] != address(0), "BountyBoard: INVALID_WINNER");
            require(_winners[i] != _creator, "BountyBoard: CREATOR_CANNOT_WIN");

            for (uint256 j = i + 1; j < _winners.length; j++) {
                require(_winners[i] != _winners[j], "BountyBoard: WINNERS_NOT_UNIQUE");
            }
        }
    }

    /**
     * @dev Internal function to verify all winners are participants
     */
    function _verifyParticipants(uint256 _bountyId, address[] calldata _winners) internal view {
        for (uint256 i = 0; i < _winners.length; i++) {
            require(isParticipant[_bountyId][_winners[i]], "BountyBoard: WINNER_NOT_PARTICIPANT");
        }
    }

    /**
     * @dev Internal function to distribute prizes
     */
    function _distributePrizes(address[] calldata _winners, uint256[] storage _prizes) internal {
        uint256 totalPrize;
        for (uint256 i = 0; i < _winners.length; i++) {
            totalPrize += _prizes[i];
        }
        require(address(this).balance >= totalPrize, "BountyBoard: INSUFFICIENT_FUNDS");

        for (uint256 i = 0; i < _winners.length; i++) {
            address winner = _winners[i];
            uint256 prize = _prizes[i];

            (bool success,) = winner.call{value: prize}("");
            require(success, "BountyBoard: TRANSFER_FAILED");
        }
    }

    /**
     * @dev Allows a participant to submit their work for a bounty
     * @param _bountyId The ID of the bounty
     * @param _cid The CID of the submission
     */
    function createSubmission(uint256 _bountyId, string memory _cid) external override {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.isActive, "BountyBoard: BOUNTY_NOT_FOUND");
        require(msg.sender != address(0), "BountyBoard: INVALID_PARTICIPANT");
        require(msg.sender != bounty.creator, "BountyBoard: CREATOR_CANNOT_SUBMIT");
        require(block.timestamp <= bounty.deadline, "BountyBoard: SUBMISSION_DEADLINE_PASSED");
        require(!isParticipant[_bountyId][msg.sender], "BountyBoard: ALREADY_PARTICIPATED");

        Submission memory newSubmission = Submission({cid: _cid, participant: msg.sender, timestamp: block.timestamp});

        bountySubmissions[_bountyId].push(newSubmission);
        isParticipant[_bountyId][msg.sender] = true;

        emit SubmissionCreated(_bountyId, _cid, msg.sender, block.timestamp);
    }

    /**
     * @dev Allows a participant to edit their submission
     * @param _bountyId The ID of the bounty
     * @param _cid The new CID of the submission
     * @param _submissionIndex The index of the submission in the array
     */
    function editSubmision(uint256 _bountyId, string memory _cid, uint256 _submissionIndex) external override {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.isActive, "BountyBoard: BOUNTY_NOT_FOUND");
        require(msg.sender != address(0), "BountyBoard: INVALID_PARTICIPANT");
        require(msg.sender != bounty.creator, "BountyBoard: CREATOR_CANNOT_SUBMIT");

        Submission storage submission = bountySubmissions[_bountyId][_submissionIndex];
        require(submission.participant == msg.sender, "BountyBoard: NOT_SUBMISSION_OWNER");

        submission.cid = _cid;

        emit SubmissionUdpated(_bountyId, _cid, msg.sender, block.timestamp);
    }

    /**
     * @dev Allows the creator to cancel a bounty
     * @param _bountyId The ID of the bounty
     */
    function cancelBounty(uint256 _bountyId) external override {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.isActive, "BountyBoard: BOUNTY_NOT_FOUND");
        require(bounty.creator == msg.sender, "BountyBoard: NOT_CREATOR");
        require(bounty.selectedWinners.length == 0, "BountyBoard: WINNERS_ALREADY_SELECTED");
        require(bounty.minParticipants > bountySubmissions[_bountyId].length, "BountyBoard: NOT_ENOUGH_PARTICIPANTS");
        require(bounty.resultDeadline < block.timestamp, "BountyBoard: RESULT_DEADLINE_NOT_REACHED");

        bounty.isActive = false;

        // Refund the creator
        uint256 totalPrize;
        for (uint256 i = 0; i < bounty.prizes.length; i++) {
            totalPrize += bounty.prizes[i];
        }

        require(address(this).balance >= totalPrize, "BountyBoard: INSUFFICIENT_FUNDS");
        (bool success,) = msg.sender.call{value: totalPrize}("");
        require(success, "BountyBoard: TRANSFER_FAILED");

        emit BountyCancelled(bounty.id);
    }

    // HELPER FUNCTIONS

    /**
     * @dev Returns the list of bounties created by a user
     * @param _bountyId bountyId
     * @return The bounty object
     */
    function getBounty(uint256 _bountyId) public view returns (Bounty memory) {
        return bounties[_bountyId];
    }

    /**
     * @dev Returns the list of bounties created by a user
     * @param _creator The address of the creator
     * @return The list of bounty IDs created by the user
     */
    function getUserBounties(address _creator) public view returns (uint256[] memory) {
        return userBounties[_creator];
    }

    /**
     * @dev Returns the list of submissions for a bounty
     * @param _bountyId The ID of the bounty
     * @return The list of submissions for the bounty
     */
    function getBountySubmissions(uint256 _bountyId) public view returns (Submission[] memory) {
        return bountySubmissions[_bountyId];
    }

    /**
     * @dev Returns the list of submissions for a bounty
     * @param _bountyId The ID of the bounty
     * @param _participant The address of the participant
     * @return True if the address is a participant, false otherwise
     */
    function isParticipantOfBounty(uint256 _bountyId, address _participant) public view returns (bool) {
        return isParticipant[_bountyId][_participant];
    }

    // ADMIN FUNCTIONS
    /**
     * @dev Allows the owner to withdraw collected fees
     * @param _amount The amount to withdraw
     */
    function withdraw(uint256 _amount) external override onlyOwner {
        require(_amount <= feeCollected, "BountyBoard: INSUFFICIENT_FUNDS");
        (bool success,) = msg.sender.call{value: _amount}("");
        require(success, "BountyBoard: TRANSFER_FAILED");
        feeCollected -= _amount;
    }

    receive() external payable {}
    fallback() external payable {}
}

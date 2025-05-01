// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Types.sol";

interface IBountyBoard {
    // Events
    event BountyCreated(
        uint256 indexed id,
        address indexed creator,
        string cid,
        uint256 deadline,
        uint256 resultDeadline,
        uint16 minParticipants,
        uint16 totalWinners,
        uint256[] prizes,
        BountyType bountyType
    );

    event BountyUpdated(
        uint256 indexed id,
        address indexed creator,
        string cid,
        uint256 deadline,
        uint256 resultDeadline,
        uint16 minParticipants,
        uint16 totalWinners,
        uint256[] prizes,
        BountyType bountyType
    );

    event WinnersSelected(uint256 indexed bountyId, address[] winners);
    event SubmissionCreated(uint256 indexed bountyId, string cid, address participant, uint256 timestamp);
    event SubmissionUdpated(uint256 indexed bountyId, string cid, address participant, uint256 timestamp);
    event BountyCancelled(uint256 indexed id);

    // Errors
    error BountyBoard__InsufficientFunds(uint256 amountUser, uint256 amountRequired);

    // Functions
    function createBounty(
        string memory _cid,
        uint256 _deadline,
        uint256 _resultDeadline,
        uint16 _minParticipants,
        uint16 _totalWinners,
        uint256[] memory _prizes,
        BountyType _bountyType
    ) external payable returns (uint256);

    function calculatePrizesAndFee(uint256[] memory _prizes)
        external
        pure
        returns (uint256 totalPrizeAmount, uint256 platformFee);

    function editBounty(
        uint256 _bountyId,
        string memory _cid,
        uint256 _deadline,
        uint256 _resultDeadline,
        uint16 _minParticipants,
        uint16 _totalWinners,
        uint256[] memory _prizes
    ) external payable;

    function selectWinners(uint256 _bountyId, address[] calldata _winners) external;
    function createSubmission(uint256 _bountyId, string memory _cid) external;
    function editSubmision(uint256 _bountyId, string memory _cid, uint256 _submissionIndex) external;
    function cancelBounty(uint256 _bountyId) external;

    // View functions
    function getBounty(uint256 _bountyId) external view returns (Bounty memory);
    function getUserBounties(address _creator) external view returns (uint256[] memory);
    function getBountySubmissions(uint256 _bountyId) external view returns (Submission[] memory);
    function isParticipantOfBounty(uint256 _bountyId, address _participant) external view returns (bool);

    // Admin functions
    function withdraw(uint256 _amount) external;

    // Fallback
    receive() external payable;
    fallback() external payable;
}

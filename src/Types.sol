// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// this is events
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

// this is errors
error BountyBoard__InsufficientFunds(uint256 amountUser, uint256 amountRequired);

// this is interfaces/types
enum BountyType {
    EDITABLE,
    NON_EDITABLE
}

enum BountyStatus {
    OPEN,
    IN_PROGRESS,
    IN_REVIEW,
    COMPLETED
}

struct Bounty {
    uint256 id;
    bool isActive;
    address creator;
    string cid;
    uint256 deadline;
    uint256 resultDeadline;
    uint16 minParticipants;
    uint16 totalWinners;
    uint256[] prizes;
    address[] selectedWinners;
    BountyStatus status;
    BountyType bountyType;
}

struct Submission {
    string cid;
    address participant;
    uint256 timestamp;
}

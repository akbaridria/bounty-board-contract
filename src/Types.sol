// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

enum BountyType {
    EDITABLE,
    NON_EDITABLE
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
    BountyType bountyType;
}

struct Submission {
    string cid;
    address participant;
    uint256 timestamp;
}

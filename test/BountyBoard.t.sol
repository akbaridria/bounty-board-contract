// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BountyBoard.sol";
import "../src/Types.sol";

contract BountyBoardTest is Test {
    BountyBoard public bountyBoard;
    address public owner = address(1);
    address public creator = address(2);
    address public participant1 = address(3);
    address public participant2 = address(4);
    address public participant3 = address(5);

    function setUp() public {
        vm.deal(creator, 100 ether);
        vm.deal(participant1, 10 ether);
        vm.deal(participant2, 10 ether);
        vm.deal(participant3, 10 ether);

        vm.prank(owner);
        bountyBoard = new BountyBoard();
    }

    // Helper function to create a bounty
    function createTestBounty(BountyType bountyType) internal returns (uint256) {
        uint256[] memory prizes = new uint256[](2);
        prizes[0] = 1 ether;
        prizes[1] = 0.5 ether;

        vm.prank(creator);
        return bountyBoard.createBounty{value: 1.575 ether}(
            "test-cid",
            block.timestamp + 7 days,
            block.timestamp + 14 days,
            2, // minParticipants
            2, // totalWinners
            prizes,
            bountyType
        );
    }

    // Test bounty creation
    function testCreateBounty() public {
        uint256[] memory prizes = new uint256[](2);
        prizes[0] = 1 ether;
        prizes[1] = 0.5 ether;

        vm.prank(creator);
        uint256 bountyId = bountyBoard.createBounty{value: 1.575 ether}(
            "test-cid", block.timestamp + 7 days, block.timestamp + 14 days, 2, 2, prizes, BountyType.EDITABLE
        );

        Bounty memory bounty = bountyBoard.getBounty(bountyId);
        assertEq(bounty.id, bountyId);
        assertEq(bounty.creator, creator);
        assertEq(bounty.isActive, true);
        assertEq(bounty.cid, "test-cid");
        assertEq(bounty.deadline, block.timestamp + 7 days);
        assertEq(bounty.resultDeadline, block.timestamp + 14 days);
        assertEq(bounty.minParticipants, 2);
        assertEq(bounty.totalWinners, 2);
        assertEq(bounty.prizes.length, 2);
        assertEq(bounty.prizes[0], 1 ether);
        assertEq(bounty.prizes[1], 0.5 ether);
        assertEq(uint256(bounty.bountyType), uint256(BountyType.EDITABLE));
    }

    // Test non-editable bounty cannot be edited
    function testCannotEditNonEditableBounty() public {
        uint256 bountyId = createTestBounty(BountyType.NON_EDITABLE);

        uint256[] memory newPrizes = new uint256[](2);
        newPrizes[0] = 0.8 ether;
        newPrizes[1] = 0.7 ether;

        vm.prank(creator);
        vm.expectRevert("BountyBoard: NON_EDITABLE_BOUNTY");
        bountyBoard.editBounty{value: 1.575 ether}(
            bountyId, "new-cid", block.timestamp + 8 days, block.timestamp + 15 days, 3, 2, newPrizes
        );
    }

    // Test submission creation
    function testCreateSubmission() public {
        uint256 bountyId = createTestBounty(BountyType.EDITABLE);

        vm.prank(participant1);
        bountyBoard.createSubmission(bountyId, "submission-cid-1");

        assertEq(bountyBoard.isParticipant(bountyId, participant1), true);

        Submission[] memory submissions = bountyBoard.getBountySubmissions(bountyId);
        assertEq(submissions.length, 1);
        assertEq(submissions[0].participant, participant1);
        assertEq(submissions[0].cid, "submission-cid-1");
    }

    // Test cannot submit after deadline
    function testCannotSubmitAfterDeadline() public {
        uint256 bountyId = createTestBounty(BountyType.EDITABLE);

        // Fast forward past deadline
        vm.warp(block.timestamp + 8 days);

        vm.prank(participant1);
        vm.expectRevert("BountyBoard: SUBMISSION_DEADLINE_PASSED");
        bountyBoard.createSubmission(bountyId, "submission-cid-1");
    }

    // Test winner selection
    function testSelectWinners() public {
        uint256 bountyId = createTestBounty(BountyType.EDITABLE);

        // Create submissions
        vm.prank(participant1);
        bountyBoard.createSubmission(bountyId, "submission-cid-1");

        vm.prank(participant2);
        bountyBoard.createSubmission(bountyId, "submission-cid-2");

        // Fast forward to after submission deadline but before result deadline
        vm.warp(block.timestamp + 8 days);

        // Select winners
        address[] memory winners = new address[](2);
        winners[0] = participant1;
        winners[1] = participant2;

        uint256 participant1BalanceBefore = participant1.balance;
        uint256 participant2BalanceBefore = participant2.balance;

        vm.prank(creator);
        bountyBoard.selectWinners(bountyId, winners);

        Bounty memory bounty = bountyBoard.getBounty(bountyId);
        assertEq(bounty.isActive, false);
        assertEq(bounty.selectedWinners.length, 2);
        assertEq(bounty.selectedWinners[0], participant1);
        assertEq(bounty.selectedWinners[1], participant2);
        assertEq(participant1.balance, participant1BalanceBefore + 1 ether);
        assertEq(participant2.balance, participant2BalanceBefore + 0.5 ether);
    }

    // Test bounty cancellation
    function testCancelBounty() public {
        uint256 bountyId = createTestBounty(BountyType.EDITABLE);

        // Create one submission (below minimum)
        vm.prank(participant1);
        bountyBoard.createSubmission(bountyId, "submission-cid-1");

        uint256 creatorBalanceBefore = creator.balance;

        // Fast forward past result deadline
        vm.warp(block.timestamp + 15 days);

        vm.prank(creator);
        bountyBoard.cancelBounty(bountyId);

        Bounty memory bounty = bountyBoard.getBounty(bountyId);
        assertEq(bounty.isActive, false);
        assertEq(creator.balance, creatorBalanceBefore + 1.5 ether);
    }

    // Test fee withdrawal by owner
    function testWithdrawFees() public {
        createTestBounty(BountyType.EDITABLE);

        // Fee should be 0.075 ether (5% of 1.5 ether)
        assertEq(bountyBoard.feeCollected(), 0.075 ether);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        bountyBoard.withdraw(0.075 ether);

        assertEq(owner.balance, ownerBalanceBefore + 0.075 ether);
        assertEq(bountyBoard.feeCollected(), 0);
    }

    // Test edge cases for winner selection
    function testSelectWinnersEdgeCases() public {
        uint256 bountyId = createTestBounty(BountyType.EDITABLE);

        // Create submissions
        vm.prank(participant1);
        bountyBoard.createSubmission(bountyId, "submission-cid-1");

        vm.prank(participant2);
        bountyBoard.createSubmission(bountyId, "submission-cid-2");

        // Fast forward to after submission deadline
        vm.warp(block.timestamp + 8 days);

        // Test invalid winner address
        address[] memory invalidWinners = new address[](2);
        invalidWinners[0] = address(0);
        invalidWinners[1] = participant2;

        vm.prank(creator);
        vm.expectRevert("BountyBoard: INVALID_WINNER");
        bountyBoard.selectWinners(bountyId, invalidWinners);
    }

    // Test editing submission
    function testEditSubmission() public {
        uint256 bountyId = createTestBounty(BountyType.EDITABLE);

        vm.prank(participant1);
        bountyBoard.createSubmission(bountyId, "submission-cid-1");

        vm.prank(participant1);
        bountyBoard.editSubmision(bountyId, "updated-cid", 0);

        Submission[] memory submissions = bountyBoard.getBountySubmissions(bountyId);
        assertEq(submissions[0].cid, "updated-cid");
    }

    // Test cannot edit someone else's submission
    function testCannotEditOthersSubmission() public {
        uint256 bountyId = createTestBounty(BountyType.EDITABLE);

        vm.prank(participant1);
        bountyBoard.createSubmission(bountyId, "submission-cid-1");

        vm.prank(participant2);
        vm.expectRevert("BountyBoard: NOT_SUBMISSION_OWNER");
        bountyBoard.editSubmision(bountyId, "updated-cid", 0);
    }
}

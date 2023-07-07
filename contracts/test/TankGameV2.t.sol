// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { TankGame } from "src/base/TankGameV2.sol";
import { ITankGame } from "src/interfaces/ITankGame.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Board } from "src/interfaces/IBoard.sol";

contract TankTest is Test {
    TankGame public tankGame;

    function setUp() public {
        ITankGame.GameSettings memory gs = ITankGame.GameSettings({
            playerCount: 8,
            boardSize: 10,
            initAPs: 3,
            initHearts: 3,
            initShootRange: 3,
            upgradeCost: 3,
            epochSeconds: 4 hours,
            voteThreshold: 3,
            actionDelaySeconds: 0,
            buyInMinimum: 0,
            revealWaitBlocks: 10,
            spawnerCooldown: 10
        });
        tankGame = new TankGame{value: 10 ether}(gs);
    }

    function initGame(uint160 offset) public {
        for (uint160 i = 1; i < 9; i++) {
            vm.label(address(i + offset), string(abi.encodePacked("tank", Strings.toString(i))));
            vm.prank(address(i + offset));
            tankGame.join();
        }
    }

    function initGame() public {
        initGame(0);
    }

    function testJoinGame() public {
        tankGame.join();
        assertEq(tankGame.playersCount(), 1);
    }

    function testJoinGameTwiceFails() public {
        tankGame.join();
        assertEq(tankGame.playersCount(), 1);
        vm.expectRevert("already joined");
        tankGame.join();
    }

    function testJoinFullGame() public {
        for (uint160 i = 0; i < 8; i++) {
            vm.prank(address(i));
            tankGame.join();
        }
        vm.expectRevert("game is full");
        tankGame.join();
    }

    function testInitGame() public {
        initGame();
        assert(tankGame.state() == ITankGame.GameState.Started);
        assertEq(tankGame.playersCount(), 8);
    }

    ///// tests for move() /////

    function testMove() public {
        initGame();
        Board.Point memory p0 = tankGame.board().getTankPosition(1);
        (,, uint256 apsBefore,) = tankGame.tanks(1);
        vm.prank(address(1));
        tankGame.move(1, Board.Point(p0.x + 1, p0.y, p0.z));
        (,, uint256 apsAfter,) = tankGame.tanks(1);
        Board.Point memory p = tankGame.board().getTankPosition(1);
        assertEq(p.x, p0.x + 1);
        assertEq(p.y, p0.y);
        assertEq(p.z, p0.z);
        assertEq(tankGame.board().getTile(p0).tankId, 0, "old tile should be empty");
        // assert that an action point was spent
        assertEq(apsBefore - apsAfter, 1);
    }

    function testMoveOutOfBounds() public {
        initGame();
        uint256 boardSize = tankGame.board().boardSize();
        vm.prank(address(1));
        vm.expectRevert("out of bounds");
        tankGame.move(1, Board.Point(boardSize + 1, boardSize + 1, boardSize + 1));
    }

    function testGetDistance() public {
        Board.Point memory p0 = Board.Point({ x: 3, y: 3, z: 3 });
        Board.Point memory p1 = Board.Point({ x: 4, y: 2, z: 3 });
        uint256 distance = tankGame.board().getDistance(p0, p1);
        assertEq(distance, 1, "distance should be 1");
        Board.Point memory p2 = Board.Point({ x: 5, y: 1, z: 3 });
        uint256 distance2 = tankGame.board().getDistance(p0, p2);
        assertEq(distance2, 2, "distance should be 2");
    }

    function testRandomPoints() public {
        for (uint256 i = 0; i < 10_000; i++) {
            uint256 seed = uint256(keccak256(abi.encodePacked(i)));
            Board.Point memory p0 = tankGame.board().randomPoint(seed);
            // console.log("random point: (%s, %s, %s)", p0.x, p0.y, p0.z);
            assertTrue(tankGame.board().isValidPoint(p0), "point should be valid");
        }
    }

    function testMoveTooFar() public {
        initGame();
        Board.Point memory p0 = tankGame.getBoard().getTankPosition(1);
        uint256 apsBefore = tankGame.getTank(1).aps;
        vm.prank(address(1));
        vm.mockCall(address(0), abi.encodeWithSelector(Board.getDistance.selector), abi.encode(4));
        vm.expectRevert("not enough action points");
        tankGame.move(1, Board.Point(p0.x + apsBefore + 1, p0.y, p0.z));
    }

    function testMoveNowhere() public {
        initGame();
        Board.Point memory p0 = tankGame.board().getTankPosition(1);
        vm.prank(address(1));
        vm.expectRevert("position occupied");
        tankGame.move(1, p0);
    }

    function testMoveToOccupied() public {
        initGame();
        // check if any are in range to collide. if not do multiple move to make this happen
        for (uint160 i = 1; i < 9; i++) {
            for (uint160 j = 1; j < 9; j++) {
                if (i == j) {
                    continue;
                }
                uint256 distance = tankGame.board().getDistanceTanks(i, j);
                if (distance < 3) {
                    Board.Point memory p0 = tankGame.board().getTankPosition(1);
                    vm.prank(address(j));
                    vm.expectRevert("position occupied");
                    tankGame.move(j, p0);
                }
            }
        }
    }

    ///// TESTs for shoot /////
    function testShoot() public {
        initGame();
        vm.prank(address(8));
        tankGame.shoot(8, 6, 1);
        (,, uint256 apsAfter,) = tankGame.tanks(8);
        (, uint256 hearts,,) = tankGame.tanks(6);
        assertEq(apsAfter, 2);
        assertEq(hearts, 2);
    }

    function testShootOutOfRange() public {
        initGame();
        vm.prank(address(1));
        vm.expectRevert("target out of range");
        tankGame.shoot(1, 8, 1);
    }

    function testShootNotEnoughAP() public {
        initGame();
        vm.prank(address(3));
        vm.expectRevert("not enough action points");
        tankGame.shoot(3, 4, 4);
    }

    function testShootDeadTank() public {
        initGame();
        vm.prank(address(5));
        tankGame.shoot(5, 3, 3);
        vm.expectRevert("tank is dead");
        tankGame.shoot(4, 3, 1);
    }

    function testShootNonexistentTank() public {
        initGame();
        vm.prank(address(5));
        vm.expectRevert("tank is dead");
        tankGame.shoot(5, 0, 1);
    }

    /// give tests ///

    function testGiveHeart() public {
        initGame();
        vm.prank(address(8));
        tankGame.give(8, 6, 1, 0);
        (, uint256 hearts,,) = tankGame.tanks(8);
        assertEq(hearts, 2);
        (, uint256 giverHearts,,) = tankGame.tanks(6);
        assertEq(giverHearts, 4);
    }

    function testGiveAps() public {
        initGame();
        vm.prank(address(8));
        tankGame.give(8, 6, 0, 1);
        (,, uint256 ap,) = tankGame.tanks(8);
        assertEq(ap, 2);
        (,, uint256 aps,) = tankGame.tanks(6);
        assertEq(aps, 4);
    }

    function testGiveOutOfRange() public {
        initGame();
        vm.prank(address(1));
        vm.expectRevert("target out of range");
        tankGame.give(1, 2, 1, 0);
    }

    function testGiveTooMuchAp() public {
        initGame();
        vm.prank(address(8));
        vm.expectRevert("not enough action points");
        tankGame.give(8, 6, 0, 4);
    }

    function testGiveTooMuchHearts() public {
        initGame();
        vm.prank(address(8));
        vm.expectRevert("not enough hearts");
        tankGame.give(8, 6, 4, 0);
    }

    /// upgrade tests ///
    function testUpgrade() public {
        initGame();
        vm.prank(address(1));
        tankGame.upgrade(1);
        (,, uint256 aps, uint256 range) = tankGame.tanks(1);
        assertEq(range, 4);
        assertEq(aps, 0);
    }

    function testUpgraadeNotEnoughAps() public {
        initGame();
        vm.prank(address(1));
        tankGame.upgrade(1);
        vm.prank(address(1));
        vm.expectRevert("not enough action points");
        tankGame.upgrade(1);
    }

    function upgradeOtherTank() public {
        initGame();
        vm.prank(address(1));
        vm.expectRevert("not tank owner");
        tankGame.upgrade(2);
    }

    /// drip tests ///
    function testDrip() public {
        initGame();
        (,,,,,,,, uint256 epochtime,,,) = tankGame.settings();
        skip(epochtime);
        vm.prank(address(1));
        tankGame.drip(1);
        (,, uint256 aps,) = tankGame.tanks(1);
        assertEq(aps, 4);
    }

    function testDripTooEarly() public {
        initGame();
        vm.prank(address(1));
        vm.expectRevert("too early to drip");
        tankGame.drip(1);
    }

    function testDripInSameEpoch() public {
        initGame();
        (,,,,,,,, uint256 epochtime,,,) = tankGame.settings();
        skip(epochtime);
        vm.prank(address(1));
        tankGame.drip(1);
        vm.prank(address(1));
        vm.expectRevert("already dripped");
        tankGame.drip(1);
    }

    /// end game tests
    function testClaim() public {
        uint160 precompileOffset = 10_000;
        initGame(precompileOffset);
        // give everyone infinite range
        (,,,,,,,, uint256 epochtime,,,) = tankGame.settings();
        skip(epochtime);
        for (uint256 j = 1; j <= 1000; j++) {
            for (uint160 i = 1; i <= 8; i++) {
                vm.startPrank(address(i + precompileOffset));
                tankGame.drip(i);
                if (j % 3 == 0) {
                    tankGame.upgrade(i);
                }
                skip(epochtime);
                vm.stopPrank();
            }
        }
        // kill everyone
        vm.startPrank(address(1 + precompileOffset));
        for (uint160 i = 2; i <= 8; i++) {
            tankGame.shoot(1, i, 3);
        }

        // number 1 wins, second is 7 and third is 8
        assertTrue(tankGame.state() == ITankGame.GameState.Ended, "game not ended");
        assertEq(tankGame.podium(0), 1, "first place is wrong");
        assertEq(tankGame.podium(1), 8, "second place is wrong");
        assertEq(tankGame.podium(2), 7, "third place is wrong");

        // do some claims
        vm.prank(address(1 + precompileOffset));
        tankGame.claim(1, address(1 + precompileOffset));

        vm.prank(address(8 + precompileOffset));
        tankGame.claim(8, address(8 + precompileOffset));

        vm.prank(address(7 + precompileOffset));
        tankGame.claim(7, address(7 + precompileOffset));

        assertEq(address(1 + precompileOffset).balance, 6 ether, "first place reward is wrong");
        assertEq(address(8 + precompileOffset).balance, 3 ether, "second place reward is wrong");
        assertEq(address(7 + precompileOffset).balance, 1 ether, "third place reward is wrong");
    }

    function testRecievePrizeDonation() public {
        uint256 prizeAmountBefore = tankGame.prizePool();
        hoax(address(1), 1 ether);
        tankGame.donate{ value: 1 ether }();
        assertEq(address(tankGame).balance - prizeAmountBefore, 1 ether);
        assertEq(tankGame.prizePool() - prizeAmountBefore, 1 ether);
    }
    /// helper

    // function _printBoard() public {
    //     uint256 boardSize = tankGame.board().boardSize();
    //     console.log("_________________________________________");
    //     for (uint256 i = 0; i < boardSize; i++) {
    //         string memory line = "| ";
    //         for (uint256 j = 0; j < boardSize; j++) {
    //             uint256 tankId = tankGame.tanksOnBoard(tankGame.pointToIndex(Board.Point(i, j)));
    //             if (tankId == 0) {
    //                 line = string.concat(line, "  | ");
    //             } else {
    //                 line = string.concat(line, Strings.toString(tankId), " | ");
    //             }
    //         }
    //         console.log(line);
    //         console.log("_________________________________________");
    //     }
    // }

    // function _printBoardIndex() public {
    //     uint256 boardSize = tankGame.settings().boardSize;
    //     for (uint256 i = 0; i < boardSize; i++) {
    //         for (uint256 j = 0; j < boardSize; j++) {
    //             uint256 tankId = tankGame.tanksOnBoard(tankGame.pointToIndex(ITankGame.Point(i, j)));
    //             console.log(i, j, tankId);
    //         }
    //     }
    // }
}

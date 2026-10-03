import XCTest
import PresenterCore
@testable import NodusPresenter

@MainActor final class DisplayLinkMotionSenderTests: XCTestCase {
    private func position(_ x: Double) -> Message { ["type": .string("toolData"), "data": .object(["tool": .string("pointer"), "x": .number(x)])] }

    func testUsesNewestPositionOncePerDisplayTick() {
        var sent: [Message] = []
        let sender = DisplayLinkMotionSender { sent.append($0) }
        defer { sender.cancel() }
        for x in 0..<120 { sender.submit(position(Double(x))) }
        XCTAssertTrue(sent.isEmpty)
        sender.tickForTesting()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?["data"]?.object?["x"]?.number, 119)
        sender.tickForTesting()
        XCTAssertEqual(sent.count, 1, "An idle display tick does not retransmit an old position")
        sender.submit(position(40)); sender.tickForTesting()
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent.last?["data"]?.object?["x"]?.number, 40)
    }
    func testGestureEndFlushesFinalPositionWithoutASecondDisplaySend() {
        var sent: [Message] = []
        let sender = DisplayLinkMotionSender { sent.append($0) }
        sender.submit(position(12)); sender.submit(position(98))
        sender.flush(); sender.tickForTesting()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?["data"]?.object?["x"]?.number, 98)
    }
    func testCancellationDoesNotSendIntoAReplacementConnection() {
        var sent: [Message] = []
        let sender = DisplayLinkMotionSender { sent.append($0) }
        sender.submit(position(12)); sender.cancel()
        sender.tickForTesting(); sender.flush()
        XCTAssertTrue(sent.isEmpty)
        sender.submit(position(93)); sender.flush()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?["data"]?.object?["x"]?.number, 93)
    }
}

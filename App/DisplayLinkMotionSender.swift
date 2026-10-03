import Foundation
import UIKit
import PresenterCore

/// Keep the newest position for the next display refresh instead of dropping
/// events according to wall-clock time. Drawing bypasses this coalescer so no
/// stroke points or start/end boundaries disappear.
@MainActor final class DisplayLinkMotionSender {
    @MainActor private final class TickTarget: NSObject {
        weak var owner: DisplayLinkMotionSender?
        @objc func tick() { owner?.displayTick() }
    }
    private var pending: Message?
    private var link: CADisplayLink?
    private let target = TickTarget()
    private let send: (Message) -> Void

    init(send: @escaping (Message) -> Void) {
        self.send = send
        target.owner = self
    }
    deinit { link?.invalidate() }
    func submit(_ position: Message) {
        pending = position
        guard link == nil else { return }
        let link = CADisplayLink(target: target, selector: #selector(TickTarget.tick))
        link.preferredFramesPerSecond = 60
        self.link = link
        link.add(to: .main, forMode: .common)
    }
    /// Gesture end and reliable commands deliver the last position first.
    func flush() {
        let position = pending
        pending = nil
        link?.invalidate(); link = nil
        if let position { send(position) }
    }
    func cancel() {
        pending = nil
        link?.invalidate(); link = nil
    }
    private func displayTick() {
        guard let position = pending else { cancel(); return }
        pending = nil
        send(position)
    }
    #if DEBUG
    func tickForTesting() { displayTick() }
    #endif
}

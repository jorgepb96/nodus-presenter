import Foundation
@preconcurrency import Network
import PresenterCore

/// A small boundary around NWBrowser, also used to exercise delayed/cancelled
/// discovery without pretending that Simulator validates physical peer Wi-Fi.
@MainActor protocol MacServiceBrowsing: AnyObject {
    var stateChanged: ((NWBrowser.State) -> Void)? { get set }
    var resultsChanged: (([NWEndpoint]) -> Void)? { get set }
    func start()
    func cancel()
}

@MainActor private final class BonjourMacBrowser: MacServiceBrowsing {
    var stateChanged: ((NWBrowser.State) -> Void)?
    var resultsChanged: (([NWEndpoint]) -> Void)?
    private let browser: NWBrowser

    init() {
        // Match Apple's custom peer-to-peer sample. Do not require an interface:
        // that would prevent includePeerToPeer from enabling all eligible paths.
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        #if DEBUG
        ConnectionDiagnostics.excludeUSB(parameters)
        #endif
        browser = NWBrowser(for: .bonjour(type: Pairing.serviceType, domain: nil), using: parameters)
    }

    func start() {
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.stateChanged?(state)
                if case .ready = state { self.resultsChanged?(self.browser.browseResults.map(\.endpoint)) }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.resultsChanged?(results.map(\.endpoint)) }
        }
        browser.start(queue: .main)
    }

    func cancel() {
        stateChanged = nil; resultsChanged = nil
        browser.stateUpdateHandler = nil; browser.browseResultsChangedHandler = nil
        browser.cancel()
    }
}

@MainActor final class MacServiceDiscovery {
    enum Outcome {
        case found(NWEndpoint)
        case unavailable
        case failed(NWError)
    }
    private let makeBrowser: () -> MacServiceBrowsing
    private var browser: MacServiceBrowsing?
    private var deadline: Task<Void, Never>?
    private var completion: ((Outcome) -> Void)?
    private var generation = UUID()
    private var permissionError: NWError?

    init(makeBrowser: (() -> MacServiceBrowsing)? = nil) {
        self.makeBrowser = makeBrowser ?? { BonjourMacBrowser() }
    }

    static func isPermissionDenied(_ error: NWError) -> Bool {
        error == .dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))
    }

    func start(service: String, timeout: Duration = .seconds(10), completion: @escaping (Outcome) -> Void) {
        cancel()
        let token = generation
        let search = makeBrowser()
        browser = search; self.completion = completion
        #if DEBUG
        ConnectionDiagnostics.record("browse-start", channel: "mac-discovery")
        #endif
        search.resultsChanged = { [weak self] endpoints in
            guard let self, self.generation == token else { return }
            // The QR identifies one exact session. Never pair with an unrelated
            // nearby service, and retain the endpoint returned by Network.
            if let endpoint = endpoints.first(where: {
                guard case .service(let name, let type, _, _) = $0 else { return false }
                return name == service && type == Pairing.serviceType
            }) {
                self.finish(.found(endpoint))
            }
        }
        search.stateChanged = { [weak self] state in
            guard let self, self.generation == token else { return }
            switch state {
            case .ready: self.permissionError = nil
            case .waiting(let error):
                #if DEBUG
                ConnectionDiagnostics.record("browse-waiting", channel: "mac-discovery", error: error)
                #endif
                // TN3179: policy denial can precede the user's response to the
                // permission alert. Keep NWBrowser alive so granting can recover.
                self.permissionError = Self.isPermissionDenied(error) ? error : nil
            case .failed(let error): self.finish(.failed(error))
            case .cancelled: self.finish(.failed(.posix(.ECANCELED)))
            default: break
            }
        }
        deadline = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled, let self, self.generation == token else { return }
            if let error = self.permissionError { self.finish(.failed(error)) }
            else { self.finish(.unavailable) }
        }
        search.start()
    }

    func cancel() {
        generation = UUID()
        completion = nil
        permissionError = nil
        deadline?.cancel(); deadline = nil
        browser?.stateChanged = nil; browser?.resultsChanged = nil
        browser?.cancel(); browser = nil
    }

    private func finish(_ outcome: Outcome) {
        let callback = completion
        // TN3213: stop peer browsing BEFORE opening the selected connection.
        // Invalidating the generation also rejects already queued callbacks.
        cancel()
        callback?(outcome)
    }
}

import Foundation
@preconcurrency import Network
import PresenterCore

/// A small boundary around NWBrowser, also used to exercise delayed/cancelled
/// discovery without pretending that Simulator validates physical peer Wi-Fi.
@MainActor protocol MacServiceBrowsing: AnyObject {
    var stateChanged: ((NWBrowser.State) -> Void)? { get set }
    var resultsChanged: (([NWEndpoint]) -> Void)? { get set }
    var scopedEndpoints: [NWEndpoint] { get }
    func start()
    func cancel()
}

extension MacServiceBrowsing {
    var scopedEndpoints: [NWEndpoint] { [] }
}

@MainActor private final class BonjourMacBrowser: MacServiceBrowsing {
    var stateChanged: ((NWBrowser.State) -> Void)?
    var resultsChanged: (([NWEndpoint]) -> Void)?
    private(set) var scopedEndpoints: [NWEndpoint] = []
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
                if case .ready = state { self.publish(self.browser.browseResults) }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.publish(results) }
        }
        browser.start(queue: .main)
    }

    private func publish(_ results: Set<NWBrowser.Result>) {
        #if DEBUG
        results.forEach { ConnectionDiagnostics.recordDiscovery($0) }
        scopedEndpoints = ConnectionDiagnostics.scopedFallback ? results.flatMap { result -> [NWEndpoint] in
            guard case .service(let name, let type, let domain, nil) = result.endpoint else { return [] }
            return result.interfaces.filter { $0.type == .wifi }.map {
                .service(name: name, type: type, domain: domain, interface: $0)
            }
        } : []
        if ConnectionDiagnostics.wifiDiscovery || ConnectionDiagnostics.scopeDiscovery {
            let wireless = results.filter { result in
                result.interfaces.contains {
                    ConnectionDiagnostics.peerDiscovery ? ConnectionDiagnostics.isSeparateWiFi($0) : $0.type == .wifi
                }
            }
            if !results.isEmpty && wireless.isEmpty {
                ConnectionDiagnostics.record("diagnostic-deferred-no-wifi-result", channel: "mac-discovery")
            }
            resultsChanged?(wireless.map { result in
                guard ConnectionDiagnostics.scopeDiscovery,
                      case .service(let name, let type, let domain, nil) = result.endpoint else {
                    return result.endpoint
                }
                let interfaces = result.interfaces.filter {
                    ConnectionDiagnostics.peerDiscovery ? ConnectionDiagnostics.isSeparateWiFi($0) : $0.type == .wifi
                }
                // This comparison must not invent a name or arbitrarily select
                // among multiple interfaces. Scope only an unambiguous result.
                guard interfaces.count == 1, let interface = interfaces.first else {
                    ConnectionDiagnostics.record("diagnostic-scope-ambiguous", channel: "mac-discovery")
                    return result.endpoint
                }
                ConnectionDiagnostics.record("diagnostic-service-scoped-to-discovery-interface", channel: "mac-discovery")
                return .service(name: name, type: type, domain: domain, interface: interface)
            })
            return
        }
        #endif
        resultsChanged?(results.map(\.endpoint))
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
    private(set) var alternativeEndpoints: [NWEndpoint] = []

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
                #if DEBUG
                ConnectionDiagnostics.record("browse-matched", channel: "mac-discovery")
                let scope = endpoint.interface.map { "\($0.type)/\($0.name)" } ?? "unscoped"
                ConnectionDiagnostics.record("selected-endpoint-scope=\(scope)", channel: "mac-discovery")
                #endif
                let alternatives = search.scopedEndpoints.filter {
                    guard case .service(let name, let type, _, _) = $0 else { return false }
                    return name == service && type == Pairing.serviceType && $0 != endpoint
                }
                self.finish(.found(endpoint), alternatives: alternatives)
            }
        }
        search.stateChanged = { [weak self] state in
            guard let self, self.generation == token else { return }
            switch state {
            case .ready:
                self.permissionError = nil
                #if DEBUG
                ConnectionDiagnostics.record("browse-ready", channel: "mac-discovery")
                #endif
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
            else {
                #if DEBUG
                ConnectionDiagnostics.record("browse-deadline-no-match", channel: "mac-discovery")
                #endif
                self.finish(.unavailable)
            }
        }
        search.start()
    }

    func cancel() {
        generation = UUID()
        completion = nil
        alternativeEndpoints = []
        permissionError = nil
        deadline?.cancel(); deadline = nil
        browser?.stateChanged = nil; browser?.resultsChanged = nil
        browser?.cancel(); browser = nil
    }

    private func finish(_ outcome: Outcome, alternatives: [NWEndpoint] = []) {
        let callback = completion
        // TN3213: stop peer browsing BEFORE opening the selected connection.
        // Invalidating the generation also rejects already queued callbacks.
        cancel()
        alternativeEndpoints = alternatives
        callback?(outcome)
    }
}

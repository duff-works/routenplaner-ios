import Foundation
import Citadel
import NIOCore
import NIOPosix
import NIOSSH

/// Confines a non-Sendable value so it can cross into the event-loop task.
/// Safe because everything is pinned to one single-threaded event-loop group.
private struct Unchecked<T>: @unchecked Sendable { let v: T }

/// Native SSH local port-forward: connect to a jump host, listen on
/// 127.0.0.1:<localPort>, and pipe each inbound connection through a per-connection
/// SSH direct-tcpip channel to <remoteHost>:<remotePort>. Reproduces Android JSch
/// `setPortForwardingL`.
///
/// A tunnel is SINGLE-USE: `connect()` once, `disconnect()` once (which also shuts
/// down the event-loop group). To reconnect (e.g. after iOS suspends the app), build
/// a fresh `SSHTunnel` — see AppState.reconnectTunnelIfNeeded.
@MainActor
final class SSHTunnel: ObservableObject {
    enum State: Equatable { case disconnected, connecting, connected, failed(String) }

    @Published private(set) var state: State = .disconnected

    private let config: SSHTunnelConfig
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var client: SSHClient?
    private var serverChannel: Channel?
    private var didShutdownGroup = false

    init(config: SSHTunnelConfig) { self.config = config }

    var isConnected: Bool { state == .connected }
    var localPort: Int { config.localPort }

    func connect() async throws {
        guard state != .connected, state != .connecting else { return }
        state = .connecting
        do {
            let auth = try makeSSHAuthMethod(config)
            let client = try await SSHClient.connect(
                host: config.host,
                port: config.port,
                authenticationMethod: auth,
                hostKeyValidator: .acceptAnything(),   // matches Android StrictHostKeyChecking=no
                reconnect: .never,                     // single-use tunnel; rebuild fresh on foreground
                algorithms: .all,                      // needed for ssh-rsa / DH-group14 servers
                group: group,
                connectTimeout: .seconds(10)
            )
            self.client = client
            try await startListener(client: client)
            state = .connected
        } catch {
            state = .failed(Self.message(for: error))
            await teardownAndShutdown()   // release channels + group; keep .failed for the UI
            throw error
        }
    }

    private func startListener(client: SSHClient) async throws {
        let boxedClient = Unchecked(v: client)
        let remoteHost = config.remoteHost
        let remotePort = config.remotePort

        let bootstrap = ServerBootstrap(group: group, childGroup: group)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .childChannelInitializer { inbound in
                let promise = inbound.eventLoop.makePromise(of: Void.self)
                let boxedInbound = Unchecked(v: inbound)
                promise.completeWithTask {
                    let inbound = boxedInbound.v
                    let (localGlue, sshGlue) = PipeGlueHandler.matchedPair()
                    let origin = try SocketAddress(ipAddress: "127.0.0.1", port: 0)
                    let sshChannel = try await boxedClient.v.createDirectTCPIPChannel(
                        using: SSHChannelType.DirectTCPIP(
                            targetHost: remoteHost,
                            targetPort: remotePort,
                            originatorAddress: origin
                        )
                    ) { sshChannel in
                        // Allow clean half-close so a backend EOF doesn't truncate the tail
                        // of a large response (M6).
                        sshChannel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true)
                            .flatMap { sshChannel.pipeline.addHandler(sshGlue) }
                    }
                    do {
                        try await inbound.pipeline.addHandler(localGlue).get()
                    } catch {
                        // Don't leak the already-opened SSH channel if wiring the local end fails (M7).
                        try? await sshChannel.close()
                        throw error
                    }
                }
                return promise.futureResult
            }

        self.serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: config.localPort).get()
    }

    func disconnect() async {
        await teardownAndShutdown()
        state = .disconnected
    }

    /// Closes the listener + client, then shuts the event-loop group down (async, off
    /// the main thread) so the port is released without relying on `deinit`.
    private func teardownAndShutdown() async {
        if let s = serverChannel {
            try? await s.close()
            serverChannel = nil
        }
        if let c = client {
            try? await c.close()
            client = nil
        }
        if !didShutdownGroup {
            didShutdownGroup = true
            try? await group.shutdownGracefully()
        }
    }

    private static func message(for error: Error) -> String {
        let s = String(describing: error).lowercased()
        if s.contains("auth") { return "Authentifizierung fehlgeschlagen. Zugangsdaten prüfen." }
        if s.contains("timeout") || s.contains("timedout") { return "Zeitüberschreitung. Server nicht erreichbar." }
        if s.contains("refused") { return "Verbindung abgelehnt. SSH-Port prüfen." }
        if s.contains("resolve") || s.contains("nodename") || s.contains("unknownhost") {
            return "SSH-Server nicht gefunden."
        }
        if s.contains("address") && s.contains("use") { return "Port bereits belegt." }
        return "SSH-Fehler: \(error)"
    }

    deinit {
        // Last resort only; disconnect() normally shuts the group down asynchronously first.
        try? group.syncShutdownGracefully()
    }
}

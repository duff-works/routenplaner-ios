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
@MainActor
final class SSHTunnel: ObservableObject {
    enum State: Equatable { case disconnected, connecting, connected, failed(String) }

    @Published private(set) var state: State = .disconnected

    private let config: SSHTunnelConfig
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var client: SSHClient?
    private var serverChannel: Channel?

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
                reconnect: .never,                     // we rebuild the tunnel ourselves on foreground
                algorithms: .all,                      // needed for ssh-rsa / DH-group14 servers
                group: group,
                connectTimeout: .seconds(10)
            )
            self.client = client
            try await startListener(client: client)
            state = .connected
        } catch {
            state = .failed(Self.message(for: error))
            await teardown()
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
                    _ = try await boxedClient.v.createDirectTCPIPChannel(
                        using: SSHChannelType.DirectTCPIP(
                            targetHost: remoteHost,
                            targetPort: remotePort,
                            originatorAddress: origin
                        )
                    ) { sshChannel in
                        sshChannel.pipeline.addHandler(sshGlue)
                    }
                    try await inbound.pipeline.addHandler(localGlue).get()
                }
                return promise.futureResult
            }

        self.serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: config.localPort).get()
    }

    func disconnect() async {
        await teardown()
        state = .disconnected
    }

    private func teardown() async {
        if let s = serverChannel {
            try? await s.close()
            serverChannel = nil
        }
        if let c = client {
            try? await c.close()
            client = nil
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
        try? group.syncShutdownGracefully()
    }
}

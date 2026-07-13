import NIOCore

/// Bidirectional byte pump between two channels on the SAME EventLoop.
/// Derived from SwiftNIO's example GlueHandler, but with EOF + full-close
/// propagation ENABLED (Citadel's vendored copy is `internal` and leaves those
/// disabled, which makes HTTP-over-tunnel sockets hang/leak).
///
/// Both handlers in a matched pair MUST live on the same event loop — guaranteed
/// here because the SSH client and the local listener share a single-threaded group.
final class PipeGlueHandler {
    private var partner: PipeGlueHandler?
    private var context: ChannelHandlerContext?
    private var pendingRead = false

    private init() {}

    static func matchedPair() -> (PipeGlueHandler, PipeGlueHandler) {
        let a = PipeGlueHandler()
        let b = PipeGlueHandler()
        a.partner = b
        b.partner = a
        return (a, b)
    }

    private func partnerWrite(_ data: NIOAny) { context?.write(data, promise: nil) }
    private func partnerFlush() { context?.flush() }
    private func partnerWriteEOF() { context?.close(mode: .output, promise: nil) }
    private func partnerCloseFull() { context?.close(promise: nil) }
    private func partnerBecameWritable() {
        if pendingRead {
            pendingRead = false
            context?.read()
        }
    }
    private var partnerWritable: Bool { context?.channel.isWritable ?? false }
}

extension PipeGlueHandler: ChannelDuplexHandler {
    typealias InboundIn = NIOAny
    typealias InboundOut = NIOAny
    typealias OutboundIn = NIOAny
    typealias OutboundOut = NIOAny

    func handlerAdded(context: ChannelHandlerContext) {
        self.context = context
        if context.channel.isWritable {
            partner?.partnerBecameWritable()
        }
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.context = nil
        partner = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        partner?.partnerWrite(data)
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        partner?.partnerFlush()
    }

    func channelInactive(context: ChannelHandlerContext) {
        partner?.partnerCloseFull()
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let event = event as? ChannelEvent, case .inputClosed = event {
            partner?.partnerWriteEOF()
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        partner?.partnerCloseFull()
    }

    func channelWritabilityChanged(context: ChannelHandlerContext) {
        if context.channel.isWritable {
            partner?.partnerBecameWritable()
        }
    }

    func read(context: ChannelHandlerContext) {
        if let partner = partner, partner.partnerWritable {
            context.read()
        } else {
            pendingRead = true
        }
    }
}

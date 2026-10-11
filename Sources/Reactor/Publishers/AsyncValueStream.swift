//
//  AsyncValueStream.swift
//  Reactor
//
//  Created by Filip Šašala on 11/10/2026.
//

import Foundation

/// An actor-isolated asynchronous value broadcaster.
///
/// Each subscriber receives an independent AsyncStream.
/// New subscribers immediately receive the latest published value,
/// followed by subsequent updates in publication order.
public actor AsyncValueStream<Value: Sendable> {

    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    private var isFinished = false

    private(set) public var value: Value?

    // MARK: - Initialization

    public init() {}

    // MARK: - Public

    /// Sends new value into valueStream and updates existing ``value`` field.
    ///
    /// If stream is finished, does nothing.
    public func send(_ value: Value) {
        guard !isFinished else { return }

        self.value = value

        for continuation in continuations.values {
            continuation.yield(value)
        }
    }

    /// Finishes the stream and removes all subscriptions.
    ///
    /// If stream is finished, does nothing.
    public func finish() {
        guard !isFinished else { return }
        self.isFinished = true

        for continuation in continuations.values {
            continuation.finish()
        }

        continuations.removeAll()
    }

    // MARK: - Subscribe

    /// Creates a new subscription to value stream and yields existing value.
    ///
    /// If stream is finished, new subscription immediately finishes.
    public func subscribe(bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy) -> AsyncStream<Value> {
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: bufferingPolicy)

        guard !isFinished else {
            continuation.finish()
            return stream
        }

        let id = UUID()
        continuation.onTermination = { [weak self] termination in
            Task { await self?.removeContinuation(id: id) }
        }

        self.continuations[id] = continuation

        if let value = self.value {
            continuation.yield(value)
        }

        return stream
    }

    // MARK: - Private

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

}

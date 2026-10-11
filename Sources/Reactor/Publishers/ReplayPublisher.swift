//
//  ReplayPublisher.swift
//  refactor
//
//  Created by Filip Šašala on 25/10/2024.
//

import Foundation

@available(iOS, introduced: 13.0, deprecated: 18.0)
@available(macOS, introduced: 10.15, deprecated: 15.0)
public actor ReplayPublisher<Value: Sendable>: Publisher {

    private let upstream: any Publisher<Value>
    private(set) public var lastValue: Value? = nil

    init(replaying upstream: any Publisher<Value>) {
        self.upstream = upstream
    }

    public func send(_ value: Value) async {
        self.lastValue = value
        await upstream.send(value)
    }

    public func finish() async {
        await upstream.finish()
    }

}

// MARK: - Connecting

public extension ReplayPublisher {

    func connect(to subscriber: Subscriber<Value>) async {
        await upstream.connect(to: subscriber)

        if let lastValue {
            await subscriber.receive(value: lastValue)
        }
    }

}

//
//  Broadcast.swift
//  refactor
//
//  Created by Filip Šašala on 25/10/2024.
//

@available(iOS, introduced: 13.0, deprecated: 18.0)
@available(macOS, introduced: 10.15, deprecated: 15.0)
@propertyWrapper public final class Broadcast<Value: Sendable> {

    public var wrappedValue: Value {
        didSet {
            projectedValue.sendAsync(wrappedValue)
        }
    }

    public var projectedValue: any Publisher<Value>

    public init(wrappedValue: Value, replayLastValue: Bool = false) {
        self.wrappedValue = wrappedValue

        if replayLastValue {
            self.projectedValue = ReplayPublisher<Value>(replaying: PassthroughPublisher())
        } else {
            self.projectedValue = PassthroughPublisher<Value>()
        }
    }

    deinit {
        projectedValue.finishAsync()
    }

}

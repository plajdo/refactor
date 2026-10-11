//
//  AsyncValueStreamTests.swift
//  ReactorTests
//
//  Created by Filip Šašala on 11/10/2026.
//

import XCTest
@testable import Reactor

final class AsyncValueStreamTests: XCTestCase {

    func testAsyncValueStreamBroadcastsValues() async {
        let valueStream = AsyncValueStream<Int>()
        let firstStream = await valueStream.subscribe(bufferingPolicy: .unbounded)
        let secondStream = await valueStream.subscribe(bufferingPolicy: .unbounded)

        await valueStream.send(1)
        await valueStream.send(2)
        await valueStream.finish()

        let firstValues = await collectValues(from: firstStream)
        let secondValues = await collectValues(from: secondStream)

        XCTAssertEqual(firstValues, [1, 2])
        XCTAssertEqual(secondValues, [1, 2])
    }

    func testAsyncValueStreamReplaysLastValue() async {
        let valueStream = AsyncValueStream<Int>()

        await valueStream.send(1)
        await valueStream.send(2)

        let stream = await valueStream.subscribe(bufferingPolicy: .unbounded)
        await valueStream.finish()

        let values = await collectValues(from: stream)

        XCTAssertEqual(values, [2])
    }

    func testAsyncValueStreamPreservesOrder() async {
        let valueStream = AsyncValueStream<Int>()
        let stream = await valueStream.subscribe(bufferingPolicy: .unbounded)

        for value in 0..<100 {
            await valueStream.send(value)
        }
        await valueStream.finish()

        let values = await collectValues(from: stream)

        XCTAssertEqual(values, Array(0..<100))
    }

    func testAsyncValueStreamFinishesSubscribers() async {
        let valueStream = AsyncValueStream<Int>()
        let firstStream = await valueStream.subscribe(bufferingPolicy: .unbounded)
        let secondStream = await valueStream.subscribe(bufferingPolicy: .unbounded)

        await valueStream.finish()

        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        let firstValue = await firstIterator.next()
        let secondValue = await secondIterator.next()

        XCTAssertNil(firstValue)
        XCTAssertNil(secondValue)
    }

    func testAsyncValueStreamHandlesLateSubscription() async {
        let valueStream = AsyncValueStream<Int>()

        await valueStream.send(1)
        await valueStream.finish()

        let stream = await valueStream.subscribe(bufferingPolicy: .unbounded)
        var iterator = stream.makeAsyncIterator()
        let value = await iterator.next()

        XCTAssertNil(value)
    }

    func testAsyncValueStreamCancellation() async {
        let valueStream = AsyncValueStream<Int>()
        let cancelledStream = await valueStream.subscribe(bufferingPolicy: .unbounded)
        let activeStream = await valueStream.subscribe(bufferingPolicy: .unbounded)
        let cancelledSubscriber = Task {
            var iterator = cancelledStream.makeAsyncIterator()
            return await iterator.next()
        }

        await Task.yield()
        cancelledSubscriber.cancel()

        let cancelledValue = await cancelledSubscriber.value
        XCTAssertNil(cancelledValue)

        await valueStream.send(42)
        await valueStream.finish()

        let activeValues = await collectValues(from: activeStream)
        XCTAssertEqual(activeValues, [42])
    }

    func testAsyncValueStreamMaintainsConsistentOrderWhenSubscribingBetweenSends() async {
        let valueStream = AsyncValueStream<Int>()

        await valueStream.send(1)
        let stream = await valueStream.subscribe(bufferingPolicy: .unbounded)
        await valueStream.send(2)
        await valueStream.finish()

        let values = await collectValues(from: stream)

        XCTAssertEqual(values, [1, 2])
    }

}

private func collectValues<Value: Sendable>(from stream: AsyncStream<Value>) async -> [Value] {
    var values: [Value] = []

    for await value in stream {
        values.append(value)
    }

    return values
}

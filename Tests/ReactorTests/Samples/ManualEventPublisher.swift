//
//  ManualEventPublisher.swift
//  GoodReactor
//
//  Created by te075262 on 01/07/2026.
//

import Foundation
import Reactor

final class ManualEventPublisher: @unchecked Sendable {

    @MainActor static let shared = ManualEventPublisher()
    let eventPublisher = Reactor::PassthroughPublisher<Int>()

}

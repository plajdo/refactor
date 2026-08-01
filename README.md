# Reactor

Reactor is a lightweight Swift architecture for predictable view models. A view reads observable state and sends events; the reactor owns every state change and side effect.

```text
View -> Action -> reduce -> State
Side effect or publisher -> Mutation -> reduce -> State
View -> Destination -> navigation
```

## Requirements

- Swift 6.3+
- iOS 13+ or macOS 11+
- iOS 17+ or macOS 14+ for the Observation-based SwiftUI APIs shown below

## Installation

Add the package and the `Reactor` product to your Swift target:

```swift
dependencies: [
    .package(
        url: "https://github.com/plajdo/refactor.git",
        from: "3.0.0"
    )
]
```

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Reactor", package: "refactor")
    ]
)
```

## View model

`State` is the complete UI snapshot and the single source of truth. Views send `Action` and `Destination` events; asynchronous results and external events return as `Mutation` values.

```swift
import Observation
import Reactor

@Observable final class ItemsViewModel: Reactor {

    typealias Event = Reactor::Event<Action, Mutation, Destination>

    // MARK: - Dependencies

    @ObservationIgnored private let itemService = ItemService()

    // MARK: - Properties

    var destination: Destination?

    // MARK: - Action

    enum Action: Sendable {

        case load

    }

    // MARK: - Mutation

    enum Mutation: Sendable {

    }

    // MARK: - Destination

    enum Destination: Sendable {

        case detail(Item.ID)

    }

    // MARK: - State

    @MainActor @Observable final class State {

        var itemsFetchingState: DataFetchingState<[Item], ItemError> = .idle

        var items: [Item] {
            return itemsFetchingState.successValue ?? []
        }

    }

    // MARK: - Lifecycle

    func makeInitialState() -> State {
        return State()
    }

    // MARK: - Reduce

    func reduce(state: inout State, event: Event) {
        switch event.kind {
        case .action(.load):
            fetch(event, \.itemsFetchingState) {
                return try await itemService.fetchItems()
            }

        case .mutation, .destination:
            break
        }
    }

}
```

Keep event payloads `Sendable`. Apply synchronous changes directly in `reduce`, and never mutate state from the view or an asynchronous closure.

## SwiftUI

Store the reactor with `@ViewModel`, read its state directly, and translate every interaction into an event. Call `start()` once to activate subscriptions declared in `transform()`.

```swift
import Reactor
import SwiftUI

struct ItemsView: View {

    @ViewModel private var viewModel = ItemsViewModel()

    var body: some View {
        List(viewModel.items) { item in
            Button(item.name) {
                viewModel.send(destination: .detail(item.id))
            }
        }
        .overlay {
            if viewModel.itemsFetchingState.isLoading {
                ProgressView()
            }
        }
        .task {
            viewModel.start()
            await viewModel.send(action: .load)
        }
    }

}
```

Use `send(action:)` to dispatch without waiting. Use `await send(action:)` when the caller must wait for side effects tracked by that event, for example in `.refreshable` or a test.

Two-way controls remain reducer-driven through `bind`:

```swift
TextField(
    "Search",
    text: viewModel.bind(\.query, action: ItemsViewModel.Action.didChangeQuery)
)
```

## Asynchronous work

Use `fetch` when one operation maps to a `DataFetchingState`. Use `run` when the result needs a mutation and additional reducer logic. Snapshot state before starting either operation—do not capture `state` across an `await`.

```swift
case .action(.load):
    let itemID = state.itemID

    fetch(event, \.itemFetchingState) { () throws(ItemError) in
        return try await itemService.fetchItem(id: itemID)
    }

case .action(.didTapSave):
    let draft = state.draft

    run(event) {
        do {
            return .didFinishSaving(try await itemService.save(draft))
        } catch {
            return .didFailSaving
        }
    }

case .mutation(.didFinishSaving(let item)):
    state.savedItem = item

case .mutation(.didFailSaving):
    state.isShowingSaveError = true
```

`fetch` manages `.loading`, `.success`, `.failure`, and cancellation automatically. Independent operations run concurrently, so use separate fetching-state properties for independent requests.

## External events

Observe cross-feature or service events with Reactor publishers. Keep `transform()` free of side effects other than `subscribe` calls.

```swift
func transform() {
    subscribe(
        to: { itemEventService.updatesPublisher },
        map: { .didReceiveUpdate($0) }
    )
}
```

Use `PassthroughPublisher` for discrete events delivered only to active subscribers. Use `@Broadcast(replayLastValue: true)` when a new subscriber should receive the latest emitted value immediately.

## Type erasure

Use `AnyReactor<Action, Destination, State>` when a view should accept multiple view-model implementations with the same public contract. It forwards to the original reactor and does not copy its state.

```swift
typealias ItemsReactor = AnyReactor<
    ItemsViewModel.Action,
    ItemsViewModel.Destination,
    ItemsViewModel.State
>

let viewModel: ItemsReactor = ItemsViewModel()
    .eraseToAnyReactor()
```

## Preview stubs

Use `Stub` for deterministic preview states without production dependencies or side effects. Create a fresh state for each preview.

```swift
let previewViewModel = Stub<ItemsViewModel>(
    supplier: {
        let state = ItemsViewModel.State()
        state.itemsFetchingState = .success([.placeholder])
        return state
    }
).eraseToAnyReactor()
```

Add a stub reducer only for small interactive preview transitions. Keep `fetch`, `run`, subscriptions, and business workflows out of preview stubs.

## Legacy support

The package also exposes `LegacyReactor` for projects using the older Combine-based implementation. New code should use the `Reactor` product.

## License

Reactor is available under the MIT License. See [LICENSE.md](LICENSE.md).

import SwiftUI
import ComposableArchitecture

enum CardErrorType: Equatable {
    case cardDeactivated
    case cardSuspended
    case cardBlocked
    case idCardInteraction(IDCardInteractionError)
    case unexpectedEvent(EIDInteractionEvent)
}

struct CardErrorState: Equatable {
    var errorType: CardErrorType
    var retry: Bool
    
    var title: String {
        switch errorType {
        case .cardDeactivated:
            return L10n.CardError.CardDeactivated.title
        case .cardSuspended:
            return L10n.CardError.CardSuspended.title
        case .cardBlocked:
            return L10n.CardError.CardBlocked.title
        case .idCardInteraction,
                .unexpectedEvent:
            return L10n.CardError.CardUnreadable.title
        }
    }
    
    var markdown: String {
        switch errorType {
        case .cardDeactivated:
            return L10n.CardError.CardDeactivated.body
        case .cardSuspended:
            return L10n.CardError.CardSuspended.body
        case .cardBlocked:
            return L10n.CardError.CardBlocked.body
        case .idCardInteraction,
                .unexpectedEvent:
            return L10n.CardError.CardUnreadable.body
        }
    }
}

enum CardErrorAction: Equatable {
    case end
    case retry
}

struct CardError: View {
    var store: Store<CardErrorState, CardErrorAction>
    
    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                DialogView(store: store.stateless,
                           title: viewStore.title,
                           message: viewStore.markdown,
                           primaryButton: .init(title: L10n.FirstTimeUser.Error.close,
                                                action: viewStore.retry ? .retry : .end))
                .interactiveDismissDisabled(!viewStore.retry)
            }.navigationBarBackButtonHidden(true)
        }
    }
}

struct SetupError_Previews: PreviewProvider {
    static var previews: some View {
        CardError(store: Store(initialState: .init(errorType: .cardDeactivated, retry: false),
                                reducer: .empty,
                                environment: AppEnvironment.preview))
        CardError(store: Store(initialState: .init(errorType: .cardSuspended, retry: false),
                                reducer: .empty,
                                environment: AppEnvironment.preview))
        CardError(store: Store(initialState: .init(errorType: .cardBlocked, retry: false),
                                reducer: .empty,
                                environment: AppEnvironment.preview))
        CardError(store: Store(initialState: .init(errorType: .unexpectedEvent(.cardRemoved), retry: true),
                               reducer: .empty,
                               environment: AppEnvironment.preview))
    }
}

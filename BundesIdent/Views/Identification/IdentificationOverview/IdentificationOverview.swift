import Analytics
import ComposableArchitecture
import SwiftUI
import TCACoordinators

typealias PINCallback = IdentifiableCallback<String>
typealias PINCANCallback = IdentifiableCallback<(String, String)>

struct IdentificationOverview: ReducerProtocol {
    @Dependency(\.uuid) var uuid
    @Dependency(\.analytics) var analytics
    enum State: Equatable, IDInteractionHandler {
        case loading(IdentificationOverviewLoading.State)
        case loaded(IdentificationOverviewLoaded.State)
        case error(IdentificationOverviewError.State)
        
        func transformToLocalAction(_ event: Result<EIDInteractionEvent, IDCardInteractionError>) -> Action? {
            switch self {
            case .loading:
                return .loading(.idInteractionEvent(event))
            case .loaded:
                return .loaded(.idInteractionEvent(event))
            case .error:
                return nil
            }
        }
        
        var canGoBackToSetupIntro: Bool {
            switch self {
            case .loading(let subState):
                return subState.canGoBackToSetupIntro
            case .loaded(let subState):
                return subState.canGoBackToSetupIntro
            case .error(let subState):
                return subState.canGoBackToSetupIntro
            }
        }
        
        var identificationInformation: IdentificationInformation {
            switch self {
            case .loading(let subState):
                return subState.identificationInformation
            case .loaded(let subState):
                return subState.identificationInformation
            case .error(let subState):
                return subState.identificationInformation
            }
        }
        
#if PREVIEW
        var availableDebugActions: [IdentifyDebugSequence] {
            get {
                guard case .loading(let loadingState) = self else { return [] }
                return loadingState.availableDebugActions
            }
            set {
                guard case .loading(var loadingState) = self else { return }
                loadingState.availableDebugActions = newValue
                self = .loading(loadingState)
            }
        }
#endif
    }
    
    enum Action: Equatable {
        case loading(IdentificationOverviewLoading.Action)
        case loaded(IdentificationOverviewLoaded.Action)
        case error(IdentificationOverviewError.Action)
        
        case onAppear
        case end
        case back
    }
    
    var body: some ReducerProtocol<State, Action> {
        Scope(state: /State.loading, action: /Action.loading) {
            IdentificationOverviewLoading()
        }
        Scope(state: /State.loaded, action: /Action.loaded) {
            IdentificationOverviewLoaded()
        }
        Reduce { state, action in
            switch action {
            case .error(.retry(expirationChecked: let expirationChecked,
                               transactionInfo: let transactionInfo)):
                state = .loading(IdentificationOverviewLoading.State(identificationInformation: state.identificationInformation,
                                                                     canGoBackToSetupIntro: state.canGoBackToSetupIntro,
                                                                     expirationChecked: expirationChecked,
                                                                     transactionInfo: transactionInfo))
                return .none
            case .error(.close):
                return Effect(value: .end)
            case .loading(.failure(error: let error, expirationChecked: let expirationChecked, transactionInfo: let transactionInfo)):
                state = .error(
                    IdentificationOverviewError.State(
                        error: error,
                        identificationInformation: state.identificationInformation,
                        canGoBackToSetupIntro: state.canGoBackToSetupIntro,
                        expirationChecked: expirationChecked,
                        transactionInfo: transactionInfo
                    )
                )
                return .trackEvent(category: "identification",
                                   action: "loadingFailed",
                                   name: "attributes",
                                   analytics: analytics)
            case .loading(.done(let request, let transactionInfo, let callback)):
                let loadedState = IdentificationOverviewLoaded.State(id: uuid.callAsFunction(),
                                                                     identificationInformation: state.identificationInformation,
                                                                     request: request,
                                                                     transactionInfo: transactionInfo,
                                                                     handler: callback,
                                                                     canGoBackToSetupIntro: state.canGoBackToSetupIntro)
                state = .loaded(loadedState)
                return .none
            default:
                return .none
            }
        }
    }
}

struct IdentificationOverviewView: View {
    
    var store: Store<IdentificationOverview.State, IdentificationOverview.Action>
    var body: some View {
        WithViewStore(store) { viewStore in
            SwitchStore(store) {
                CaseLet(state: /IdentificationOverview.State.loading,
                        action: IdentificationOverview.Action.loading) { loadingStore in
                    IdentificationOverviewLoadingView(store: loadingStore)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                CaseLet(state: /IdentificationOverview.State.loaded,
                        action: IdentificationOverview.Action.loaded) { loadedStore in
                    IdentificationOverviewLoadedView(store: loadedStore)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                CaseLet(state: /IdentificationOverview.State.error,
                        action: IdentificationOverview.Action.error) { errorStore in
                    IdentificationOverviewErrorView(store: errorStore)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewStore.canGoBackToSetupIntro {
                        BackButton {
                            ViewStore(store.stateless).send(.back)
                        }
                    } else {
                        Button(L10n.Identification.end) {
                            ViewStore(store.stateless).send(.end)
                        }
                        .bodyLRegular(color: .accentColor)
                    }
                }
            }
        }
    }
}

#if PREVIEW
private let demoTokenURLWithoutScheme = "127.0.0.1:24727/eID-Client?tcTokenURL=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fv1%2Ftc-tokens%2F69f884da-b487-40cf-91f8-e8a0142249a6&widgetSessionId=c1eda54c-2a5c-4e03-8e3c-5000148b280e&tokenId=tokenId"

/// Demo url with scheme `bundesident`
let demoTokenURL = URL(string: "bundesident://\(demoTokenURLWithoutScheme)")!

/// Demo url with scheme `http`
let demoTCTokenURL = URL(string: "http://\(demoTokenURLWithoutScheme)")!
#endif

struct IdentificationOverview_Previews: PreviewProvider {
    static var previews: some View {
        IdentificationOverviewView(store: .init(initialState: IdentificationOverview.State.loading(IdentificationOverviewLoading.State(identificationInformation: .preview,
                                                                                                                                       canGoBackToSetupIntro: false)),
                                                reducer: IdentificationOverview()))
            .previewDisplayName("Loading")
        IdentificationOverviewView(store: .init(initialState: IdentificationOverview.State.loaded(IdentificationOverviewLoaded.State(id: UUID(), identificationInformation: .preview, request: EIDAuthenticationRequest.preview, transactionInfo: .preview, handler: IdentifiableCallback(id: UUID(), callback: { _ in }))),
                                                reducer: IdentificationOverview()))
            .previewDisplayName("Loaded")
    }
}

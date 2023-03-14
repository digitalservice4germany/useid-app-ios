import ComposableArchitecture
import Sentry
import SwiftUI

enum IdentificationOverviewLoadingError: Error {
    case invalidToken
    case invalidTransactionInfo
}

struct IdentificationOverviewLoading: ReducerProtocol {
    @Dependency(\.uuid) var uuid
    @Dependency(\.issueTracker) var issueTracker
    @Dependency(\.apiController) var apiController
    
    struct State: Equatable {
        var identificationInformation: IdentificationInformation
        var onAppearCalled: Bool
        var canGoBackToSetupIntro: Bool
        
        var expirationChecked: Bool
        var transactionInfo: TransactionInfo?
        
        init(identificationInformation: IdentificationInformation, onAppearCalled: Bool = false, canGoBackToSetupIntro: Bool = false, expirationChecked: Bool = false, transactionInfo: TransactionInfo? = nil) {
            self.identificationInformation = identificationInformation
            self.onAppearCalled = onAppearCalled
            self.canGoBackToSetupIntro = canGoBackToSetupIntro
            self.expirationChecked = expirationChecked
            self.transactionInfo = transactionInfo
        }
        
#if PREVIEW
        var availableDebugActions: [IdentifyDebugSequence] = []
#endif
        
        func failureAction(error: Error) -> Action {
            .failure(error: IdentifiableError(error),
                     expirationChecked: expirationChecked,
                     transactionInfo: transactionInfo)
        }
    }
    
    enum Action: Equatable {
        case onAppear
        case identify
        case validateTokenURL
        case validatedTokenURL(TaskResult<Bool>)
        case retrieveTransactionInfo
        case retrievedTransactionInfo(TaskResult<TransactionInfo>)
        case idInteractionEvent(Result<EIDInteractionEvent, IDCardInteractionError>)
        case done(EIDAuthenticationRequest, TransactionInfo, IdentifiableCallback<FlaggedAttributes>)
        case failure(error: IdentifiableError, expirationChecked: Bool, transactionInfo: TransactionInfo?)
#if PREVIEW
        case runDebugSequence(IdentifyDebugSequence)
#endif
    }
    
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .onAppear:
            guard !state.onAppearCalled else {
                return .none
            }
            state.onAppearCalled = true
            return .task { [expirationChecked = state.expirationChecked, transactionInfo = state.transactionInfo] in
                guard expirationChecked else { return .validateTokenURL }
                guard transactionInfo != nil else { return .retrieveTransactionInfo }
                return .identify
            }
        case .validateTokenURL:
            return .task { [identificationInformation = state.identificationInformation] in
                let result = await TaskResult {
                    try await apiController.validateTCTokenURL(sessionId: identificationInformation.useIDSessionId,
                                                               tokenId: identificationInformation.tokenId)
                }
                return .validatedTokenURL(result)
            }
        case .validatedTokenURL(.success(true)):
            state.expirationChecked = true
            return EffectTask(value: .retrieveTransactionInfo)
        case .validatedTokenURL(.success(false)):
            state.expirationChecked = false
            let error = IdentificationOverviewLoadingError.invalidToken
            return EffectTask(value: state.failureAction(error: error))
        case .validatedTokenURL(.failure(let error)):
            return EffectTask(value: state.failureAction(error: error))
        case .retrieveTransactionInfo:
            return .task { [sessionId = state.identificationInformation.useIDSessionId] in
                await .retrievedTransactionInfo(TaskResult {
                    try await apiController.retrieveTransactionInfo(sessionId: sessionId)
                })
            }
        case .retrievedTransactionInfo(.success(let transactionInfo)):
            state.transactionInfo = transactionInfo
            return .task {
                .identify
            }
        case .retrievedTransactionInfo(.failure(let error)):
            return EffectTask(value: state.failureAction(error: error))
        case .identify:
            return .none
        case .idInteractionEvent(.success(.requestAuthenticationRequestConfirmation(let request, let handler))):
            guard let transactionInfo = state.transactionInfo else {
                return Effect(value: state.failureAction(error: IdentificationOverviewLoadingError.invalidTransactionInfo))
            }
            return EffectTask(value: .done(request, transactionInfo, IdentifiableCallback(id: uuid.callAsFunction(), callback: handler)))
        case .idInteractionEvent(.failure(let error)):
            RedactedIDCardInteractionError(error).flatMap(issueTracker.capture(error:))
            return EffectTask(value: state.failureAction(error: error))
        case .idInteractionEvent:
            return .none
        case .done:
            return .none
        case .failure:
            return .none
#if PREVIEW
        case .runDebugSequence:
            return .none
#endif
        }
    }
}
struct IdentificationOverviewLoadingView: View {
    var store: Store<IdentificationOverviewLoading.State, IdentificationOverviewLoading.Action>
    
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.blue900))
                .scaleEffect(3)
                .frame(maxWidth: .infinity)
                .padding(50)
            VStack(spacing: 24) {
                Text(L10n.Identification.FetchMetadata.pleaseWait)
                    .bodyLRegular()
            }
            .padding(.bottom, 50)
        }
        .onAppear {
            ViewStore(store.stateless).send(.onAppear)
        }
#if PREVIEW
            .identifyDebugMenu(store: store.scope(state: \.availableDebugActions), action: IdentificationOverviewLoading.Action.runDebugSequence)
#endif
    }
}

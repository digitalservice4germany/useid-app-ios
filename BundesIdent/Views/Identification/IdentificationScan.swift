import SwiftUI
import ComposableArchitecture
import Combine
import Sentry

enum IdentificationScanError: Error, Equatable {
    case idCardInteraction(IDCardInteractionError)
    case unexpectedEvent(EIDInteractionEvent)
}

struct IdentificationScanState: Equatable, IDInteractionHandler {
    let request: EIDAuthenticationRequest
    
    var pin: String
    var pinCallback: PINCallback
    
    var shared: SharedScanState = SharedScanState()
    
    var authenticationSuccessful = false
    var alert: AlertState<IdentificationScanAction>?
#if PREVIEW
    var availableDebugActions: [IdentifyDebugSequence] = []
#endif
    
    func transformToLocalAction(_ event: Result<EIDInteractionEvent, IDCardInteractionError>) -> IdentificationScanAction? {
        return .scanEvent(event)
    }
}

enum IdentificationScanAction: Equatable {
    case onAppear
    case shared(SharedScanAction)
    case scanEvent(Result<EIDInteractionEvent, IDCardInteractionError>)
    case wrongPIN(remainingAttempts: Int)
    case identifiedSuccessfully(redirectURL: URL)
    case error(ScanErrorState)
    case cancelIdentification
    case dismiss
    case dismissAlert
#if PREVIEW
    case runDebugSequence(IdentifyDebugSequence)
#endif
}

let identificationScanReducer = Reducer<IdentificationScanState, IdentificationScanAction, AppEnvironment> { state, action, environment in
    switch action {
    case .shared(.startScan):
        state.shared.showInstructions = false
        
        guard !state.shared.isScanning else { return .none }
        state.pinCallback(state.pin)
        state.shared.isScanning = true
        
        return .trackEvent(category: "identification",
                           action: "buttonPressed",
                           name: "scan",
                           analytics: environment.analytics)
    case .scanEvent(.success(let event)):
        return state.handle(event: event, environment: environment)
    case .scanEvent(.failure(let error)):
        RedactedIDCardInteractionError(error).flatMap(environment.issueTracker.capture(error:))
        
        state.shared.isScanning = false
        switch error {
        case .cardDeactivated:
            return Effect(value: .error(ScanErrorState(errorType: .cardDeactivated, retry: false)))
        case .cardBlocked:
            return Effect(value: .error(ScanErrorState(errorType: .cardBlocked, retry: false)))
        default:
            return Effect(value: .error(ScanErrorState(errorType: .idCardInteraction(error), retry: false)))
        }
    case .wrongPIN:
        state.shared.isScanning = false
        return .none
    case .identifiedSuccessfully(let redirectURL):
        environment.storageManager.updateSetupCompleted(true)
        
        return .concatenate(.trackEvent(category: "identification", action: "success", analytics: environment.analytics),
                            .openURL(redirectURL, urlOpener: environment.urlOpener),
                            Effect(value: .dismiss))
    case .shared(.showNFCInfo):
        state.alert = AlertState(title: TextState(L10n.HelpNFC.title),
                                        message: TextState(L10n.HelpNFC.body),
                                        dismissButton: .cancel(TextState(L10n.General.ok),
                                                               action: .send(.dismissAlert)))
        
        return .trackEvent(category: "identification",
                           action: "alertShown",
                           name: "NFCInfo",
                           analytics: environment.analytics)
    case .cancelIdentification:
        state.alert = AlertState(title: TextState(verbatim: L10n.Identification.ConfirmEnd.title),
                                 message: TextState(verbatim: L10n.Identification.ConfirmEnd.message),
                                 primaryButton: .destructive(TextState(verbatim: L10n.Identification.ConfirmEnd.confirm),
                                                             action: .send(.dismiss)),
                                 secondaryButton: .cancel(TextState(verbatim: L10n.Identification.ConfirmEnd.deny)))
        return .none
    case .dismissAlert:
        state.alert = nil
        return .none
    default:
        return .none
    }
}

extension IdentificationScanState {
    mutating func handle(event: EIDInteractionEvent, environment: AppEnvironment) -> Effect<IdentificationScanAction, Never> {
        switch event {
        case .requestPIN(remainingAttempts: let remainingAttempts, pinCallback: let callback):
            pinCallback = PINCallback(id: environment.uuidFactory(), callback: callback)
            shared.isScanning = false
            shared.scanAvailable = true
            
            // This is our signal that the user canceled (for now)
            guard let remainingAttempts = remainingAttempts else {
                return .none
            }
            
            return Effect(value: .wrongPIN(remainingAttempts: remainingAttempts))
        case .requestPINAndCAN:
            shared.isScanning = false
            shared.scanAvailable = false
            return Effect(value: .error(ScanErrorState(errorType: .cardSuspended, retry: shared.scanAvailable)))
        case .requestCardInsertion,
                .authenticationStarted,
                .cardInteractionComplete,
                .cardRecognized:
            shared.isScanning = true
            return .none
        case .authenticationSuccessful:
            shared.isScanning = true
            authenticationSuccessful = true
            return .none
        case .cardRemoved:
            authenticationSuccessful = false
            return .none
        case .processCompletedSuccessfullyWithRedirect(let redirect):
            return Effect(value: .identifiedSuccessfully(redirectURL: redirect))
        case .processCompletedSuccessfullyWithoutRedirect:
            shared.scanAvailable = false
            return Effect(value: .error(ScanErrorState(errorType: .unexpectedEvent(event), retry: shared.scanAvailable)))
        default:
            return .none
        }
    }
}

struct IdentificationScan: View {
    
    var store: Store<IdentificationScanState, IdentificationScanAction>
    
    var body: some View {
        SharedScan(store: store.scope(state: \.shared, action: IdentificationScanAction.shared),
                   instructionsTitle: L10n.Identification.ScanInstructions.title,
                   instructionsBody: L10n.Identification.ScanInstructions.body,
                   instructionsScanButtonTitle: L10n.Identification.Scan.scan,
                   scanTitle: L10n.Identification.Scan.title,
                   scanBody: L10n.Identification.Scan.message,
                   scanButton: L10n.Identification.Scan.scan)
        .onAppear {
            ViewStore(store).send(.onAppear)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.General.cancel) {
                    ViewStore(store).send(.cancelIdentification)
                }
            }
        }
#if PREVIEW
        .identifyDebugMenu(store: store.scope(state: \.availableDebugActions), action: IdentificationScanAction.runDebugSequence)
#endif
        .alert(store.scope(state: \.alert), dismiss: .dismissAlert)
    }
}

struct IdentificationScan_Previews: PreviewProvider {
    static var previews: some View {
        IdentificationScan(store: Store(initialState: IdentificationScanState(request: .preview,
                                                                              pin: "123456",
                                                                              pinCallback: PINCallback(id: .zero, callback: { _ in })),
                                        reducer: .empty,
                                        environment: AppEnvironment.preview))
        IdentificationScan(store: Store(initialState: IdentificationScanState(request: .preview,
                                                                              pin: "123456",
                                                                              pinCallback: PINCallback(id: .zero, callback: { _ in }), shared: SharedScanState(isScanning: true)),
                                        reducer: .empty,
                                        environment: AppEnvironment.preview))
    }
}

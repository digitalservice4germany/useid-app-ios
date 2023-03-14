import Analytics
import Combine
import ComposableArchitecture
import Cuckoo
import TCACoordinators
import XCTest

@testable import BundesIdent

class IdentificationCoordinatorTests: XCTestCase {
    
    var scheduler: TestSchedulerOf<DispatchQueue>!
    var mockIDInteractionManager: MockIDInteractionManagerType!
    var mockStorageManager: MockStorageManagerType!
    var mockAnalyticsClient: MockAnalyticsClient!
    var mockPreviewIDInteractionManager: MockPreviewIDInteractionManagerType!
    var openedURL: URL?
    var urlOpener: ((URL) -> Void)!
    
    override func setUp() {
        mockIDInteractionManager = MockIDInteractionManagerType()
        mockStorageManager = MockStorageManagerType()
        scheduler = DispatchQueue.test
        mockAnalyticsClient = MockAnalyticsClient()
        mockPreviewIDInteractionManager = MockPreviewIDInteractionManagerType()
        urlOpener = { self.openedURL = $0 }
        
        stub(mockStorageManager) {
            when($0.setupCompleted.set(any())).thenDoNothing()
        }
        
        stub(mockAnalyticsClient) {
            $0.track(view: any()).thenDoNothing()
            $0.track(event: any()).thenDoNothing()
        }
        
        stub(mockPreviewIDInteractionManager) {
            $0.isDebugModeEnabled.get.thenReturn(false)
        }
    }
    
    override func tearDown() {
        openedURL = nil
    }
    
    func testOverviewLoadingSuccess() throws {
        let store = TestStore(initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL),
                              reducer: IdentificationCoordinator())
        store.dependencies.uuid = .incrementing
        let request = EIDAuthenticationRequest.preview
        let closure = { (attributes: FlaggedAttributes) in }
        let callback = IdentifiableCallback<FlaggedAttributes>(id: UUID(number: 0), callback: closure)
        
        store.send(.idInteractionEvent(.success(.requestAuthenticationRequestConfirmation(request, closure))))
        
        store.receive(.routeAction(0, action: .overview(.loading(.idInteractionEvent(.success(.requestAuthenticationRequestConfirmation(request, closure)))))))
        
        store.receive(.routeAction(0, action: .overview(.loading(.done(request, callback))))) {
            $0.routes = [
                .sheet(.overview(.loaded(.init(id: UUID(number: 1), request: request, handler: callback))))
            ]
        }
    }
    
    func testOverviewLoadedToPINEntry() throws {
        let request = EIDAuthenticationRequest.preview
        let closure = { (attributes: FlaggedAttributes) in }
        let callback = IdentifiableCallback<FlaggedAttributes>(id: UUID(number: 0), callback: closure)
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          states: [
                                                              .root(.overview(.loaded(.init(id: UUID(number: 0),
                                                                                            request: request,
                                                                                            handler: callback))))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        
        let pinCallback = PINCallback(id: UUID(number: 1), callback: { pin in })
        store.send(.routeAction(0, action: .overview(.loaded(.callbackReceived(request, pinCallback))))) {
            $0.routes.append(.push(.personalPIN(IdentificationPersonalPIN.State(request: request, callback: pinCallback))))
        }
    }
    
    func testPINEntryToScanFirstTime() throws {
        let request = EIDAuthenticationRequest.preview
        let callback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          states: [
                                                              .root(.personalPIN(.init(request: request,
                                                                                       callback: callback)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        store.dependencies.storageManager = mockStorageManager
        stub(mockStorageManager) {
            $0.identifiedOnce.get.thenReturn(false)
        }
        
        store.send(.routeAction(0, action: .personalPIN(.done(request: request, pin: "123456", pinCallback: callback)))) {
            $0.pin = "123456"
            $0.routes.append(.push(.scan(IdentificationPINScan.State(request: request, pin: "123456", pinCallback: callback))))
        }
    }
    
    func testPINEntryToScanAfterIdentifyingOnce() throws {
        let request = EIDAuthenticationRequest.preview
        let callback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          states: [
                                                              .root(.personalPIN(.init(request: request,
                                                                                       callback: callback)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        store.dependencies.storageManager = mockStorageManager
        stub(mockStorageManager) {
            $0.identifiedOnce.get.thenReturn(true)
        }
        
        store.send(.routeAction(0, action: .personalPIN(.done(request: request, pin: "123456", pinCallback: callback)))) {
            $0.pin = "123456"
            $0.routes.append(.push(.scan(IdentificationPINScan.State(
                request: request,
                pin: "123456",
                pinCallback: callback,
                shared: SharedScan.State(showInstructions: false)
            ))))
        }
    }
    
    func testScanSuccess() throws {
        let redirect = URL(string: "https://example.com")!
        let pin = "123456"
        let request = EIDAuthenticationRequest.preview
        let callback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.scan(.init(request: request,
                                                                                pin: pin,
                                                                                pinCallback: callback)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        store.dependencies.urlOpener = urlOpener
        store.dependencies.storageManager = mockStorageManager
        store.dependencies.analytics = mockAnalyticsClient
        stub(mockStorageManager) {
            $0.identifiedOnce.get.thenReturn(false)
            $0.identifiedOnce.set(any()).thenDoNothing()
        }
        
        store.send(.routeAction(0, action: .scan(.identifiedSuccessfully(request: request, redirectURL: redirect))))
        store.receive(.routeAction(0, action: IdentificationScreen.Action.scan(IdentificationPINScan.Action.dismiss)))
        
        XCTAssertEqual(redirect, openedURL)
        verify(mockStorageManager).setupCompleted.set(true)
        verify(mockStorageManager).identifiedOnce.set(true)
        verify(mockAnalyticsClient).track(event: AnalyticsEvent(category: "identification", action: "success"))
    }
    
    func testScanToIncorrectPIN() throws {
        let pin = "123456"
        let request = EIDAuthenticationRequest.preview
        let callback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.scan(.init(request: request,
                                                                                pin: pin,
                                                                                pinCallback: callback)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        
        store.send(.routeAction(0, action: .scan(.wrongPIN(remainingAttempts: 2)))) {
            $0.routes.append(.sheet(.incorrectPersonalPIN(.init(error: .incorrect, remainingAttempts: 2))))
        }
    }
    
    func testScanToError() throws {
        let pin = "123456"
        let request = EIDAuthenticationRequest.preview
        let callback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.scan(.init(request: request,
                                                                                pin: pin,
                                                                                pinCallback: callback)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        
        let errorState = ScanError.State(errorType: .cardBlocked, retry: false)
        store.send(.routeAction(0, action: .scan(.error(errorState)))) {
            $0.routes.append(.sheet(.error(errorState)))
        }
    }
    
    func testIncorrectPINToScan() throws {
        let pin = "123456"
        let request = EIDAuthenticationRequest.preview
        let callback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.scan(.init(request: request,
                                                                                pin: pin,
                                                                                pinCallback: callback))),
                                                              .sheet(.incorrectPersonalPIN(IdentificationIncorrectPersonalPIN.State(enteredPIN: "112233", remainingAttempts: 2)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        
        store.send(.routeAction(1, action: .incorrectPersonalPIN(.done(pin: "112233")))) {
            guard case .scan(var scanState) = $0.routes[0].screen else { return XCTFail("Unexpected state") }
            $0.attempt += 1
            $0.pin = "112233"
            scanState.shared.attempt = $0.attempt
            scanState.pin = $0.pin!
            $0.routes = [.root(.scan(scanState))]
        }
    }
    
    func testOverviewIdentify() {
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          states: [
                                                              .root(.overview(.loading(IdentificationOverviewLoading.State())))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        store.dependencies.mainQueue = scheduler.eraseToAnyScheduler()
        store.dependencies.idInteractionManager = mockIDInteractionManager
        store.dependencies.previewIDInteractionManager = mockPreviewIDInteractionManager
        
        let subject = PassthroughSubject<EIDInteractionEvent, IDCardInteractionError>()
        stub(mockIDInteractionManager) {
            $0.identify(tokenURL: demoTokenURL, nfcMessagesProvider: any()).thenReturn(subject.eraseToAnyPublisher())
        }
        
        store.send(.routeAction(0, action: .overview(.loading(.identify))))
        
        subject.send(.authenticationStarted)
        subject.send(completion: .finished)
        
        scheduler.advance()
        
        store.receive(.idInteractionEvent(.success(.authenticationStarted)))
        store.receive(.routeAction(0, action: .overview(.loading(.idInteractionEvent(.success(.authenticationStarted))))))
    }
    
    func testEndOnIncorrectPIN() {
        let pin = "123456"
        let request = EIDAuthenticationRequest.preview
        let callback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.scan(IdentificationPINScan.State(request: request, pin: pin, pinCallback: callback))),
                                                              .sheet(.incorrectPersonalPIN(IdentificationIncorrectPersonalPIN.State(remainingAttempts: 2)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        
        store.send(.routeAction(1, action: .incorrectPersonalPIN(IdentificationIncorrectPersonalPIN.Action.end))) {
            guard case .incorrectPersonalPIN(var incorrectPersonalPINState) = $0.routes[1].screen else { return XCTFail("Unexpected state") }
            incorrectPersonalPINState.alert = AlertState.confirmEndInIdentification(.confirmEnd)
            $0.routes[1].screen = .incorrectPersonalPIN(incorrectPersonalPINState)
        }
    }
    
    func testConfirmEndOnIncorrectPIN() {
        let pin = "123456"
        let request = EIDAuthenticationRequest.preview
        let callback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.scan(IdentificationPINScan.State(request: request, pin: pin, pinCallback: callback))),
                                                              .sheet(.incorrectPersonalPIN(IdentificationIncorrectPersonalPIN.State(remainingAttempts: 2)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        store.dependencies.mainQueue = scheduler.eraseToAnyScheduler()
        store.send(.routeAction(1, action: .incorrectPersonalPIN(IdentificationIncorrectPersonalPIN.Action.confirmEnd))) {
            $0.routes.removeLast()
        }
        
        scheduler.advance(by: 0.65)
        
        store.receive(.afterConfirmEnd)
    }
    
    func testSwipeToDismissTriggersConfirmation() {
        let pin = "123456"
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.overview(.loading(IdentificationOverviewLoading.State()))),
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        
        store.send(.swipeToDismiss) {
            $0.alert = AlertState.confirmEndInIdentification(.dismiss)
        }
    }
    
    func testEnterIncorrectPINToPinForgotten() throws {
        let pin = "123456"
        let request = EIDAuthenticationRequest.preview
        let pinCallback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let newPINCANCallback = PINCANCallback(id: UUID(number: 1), callback: { _, _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.scan(.init(request: request,
                                                                                pin: pin,
                                                                                pinCallback: pinCallback))),
                                                              .sheet(.incorrectPersonalPIN(IdentificationIncorrectPersonalPIN.State(enteredPIN: "112233", remainingAttempts: 2)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        
        store.send(.routeAction(1, action: .incorrectPersonalPIN(.done(pin: "112233")))) {
            guard case .scan(var scanState) = $0.routes[0].screen else { return XCTFail("Unexpected state") }
            $0.attempt += 1
            $0.pin = "112233"
            scanState.shared.attempt = $0.attempt
            scanState.pin = $0.pin!
            $0.routes = [.root(.scan(scanState))]
        }
        
        store.send(.routeAction(0, action: .scan(.requestPINAndCAN(request, newPINCANCallback)))) {
            $0.routes.append(.push(.identificationCANCoordinator(.init(tokenURL: $0.tokenURL,
                                                                       request: request,
                                                                       pinCANCallback: newPINCANCallback,
                                                                       pin: nil,
                                                                       attempt: $0.attempt,
                                                                       goToCanIntroScreen: false))))
        }
    }
    
    func testRequestPINAndCANFromImmediateThirdAttemptToCANIntro() throws {
        let pin = "123456"
        let request = EIDAuthenticationRequest.preview
        let pinCallback = PINCallback(id: UUID(number: 0), callback: { _ in })
        let newPINCANCallback = PINCANCallback(id: UUID(number: 1), callback: { _, _ in })
        let store = TestStore(
            initialState: IdentificationCoordinator.State(tokenURL: demoTokenURL,
                                                          pin: pin,
                                                          states: [
                                                              .root(.personalPIN(.init(request: request, callback: pinCallback))),
                                                              .push(.scan(.init(request: request, pin: pin, pinCallback: pinCallback)))
                                                          ]),
            reducer: IdentificationCoordinator()
        )
        
        store.send(.routeAction(1, action: .scan(.requestPINAndCAN(request, newPINCANCallback)))) {
            $0.routes.append(.push(.identificationCANCoordinator(.init(tokenURL: $0.tokenURL,
                                                                       request: request,
                                                                       pinCANCallback: newPINCANCallback,
                                                                       pin: $0.pin!,
                                                                       attempt: $0.attempt,
                                                                       goToCanIntroScreen: true))))
        }
    }
}

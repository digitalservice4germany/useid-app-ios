import XCTest
import ComposableArchitecture
import TCACoordinators
import Cuckoo
import Combine
import Analytics

@testable import BundesIdent

class SetupCANScanTests: XCTestCase {
    
    var mockAnalyticsClient: MockAnalyticsClient!
    var mockIssueTracker: MockIssueTracker!
    var mockStorageManager: MockStorageManagerType!
    var mockEIDInteractionManager: MockEIDInteractionManagerType!
    var mockPreviewEIDInteractionManager: MockPreviewEIDInteractionManagerType!
    
    override func setUp() {
        mockAnalyticsClient = MockAnalyticsClient()
        mockIssueTracker = MockIssueTracker()
        mockStorageManager = MockStorageManagerType()
        mockEIDInteractionManager = MockEIDInteractionManagerType()
        mockPreviewEIDInteractionManager = MockPreviewEIDInteractionManagerType()
        
        stub(mockAnalyticsClient) {
            $0.track(view: any()).thenDoNothing()
            $0.track(event: any()).thenDoNothing()
        }
        
        stub(mockIssueTracker) {
            $0.addBreadcrumb(crumb: any()).thenDoNothing()
            $0.capture(error: any()).thenDoNothing()
        }
        
        stub(mockStorageManager) {
            when($0.setupCompleted.set(true)).thenDoNothing()
        }
        
        stub(mockPreviewEIDInteractionManager) {
            $0.isDebugModeEnabled.get.thenReturn(false)
        }
        
        stub(mockEIDInteractionManager) {
            $0.setCAN(any()).thenDoNothing()
            $0.setPIN(any()).thenDoNothing()
        }
    }
    
    func testStartScan() throws {
        let can = "111111"
        let store = TestStore(initialState: SetupCANScan.State(transportPIN: "12345", newPIN: "123456", can: can),
                              reducer: SetupCANScan())
        store.dependencies.analytics = mockAnalyticsClient
        store.dependencies.eIDInteractionManager = mockEIDInteractionManager
        stub(mockEIDInteractionManager) { mock in
            mock.setCAN(anyString()).thenDoNothing()
        }

        store.send(.shared(.startScan)) {
            $0.shared.preventSecondScanningAttempt = true
        }
        
        verify(mockEIDInteractionManager).setCAN(can)
        verify(mockAnalyticsClient).track(event: AnalyticsEvent(category: "Setup",
                                                                action: "buttonPressed",
                                                                name: "canScan"))
        verifyNoMoreInteractions(mockEIDInteractionManager)
    }
    
    func testChangePINWithCANSuccess() throws {
        let oldPIN = "12345"
        let newPIN = "123456"
        let can = "111111"
        
        let store = TestStore(initialState: SetupCANScan.State(transportPIN: oldPIN, newPIN: newPIN, can: can),
                              reducer: SetupCANScan())
        store.dependencies.analytics = mockAnalyticsClient
        store.dependencies.storageManager = mockStorageManager
        store.dependencies.eIDInteractionManager = mockEIDInteractionManager

        stub(mockEIDInteractionManager) { mock in
            mock.setCAN(anyString()).thenDoNothing()
            mock.setPIN(anyString()).thenDoNothing()
            mock.setNewPIN(anyString()).thenDoNothing()
        }

        store.send(.shared(.startScan)) {
            $0.shared.preventSecondScanningAttempt = true
        }
        
        store.send(.scanEvent(.success(.identificationStarted)))
        store.send(.scanEvent(.success(.cardInsertionRequested)))
        
        store.send(.scanEvent(.success(.cardRecognized))) {
            $0.shared.cardRecognized = true
        }
        
        store.send(.scanEvent(.success(.pinRequested(remainingAttempts: 1))))
        store.send(.scanEvent(.success(.newPINRequested)))
        store.send(.scanEvent(.success(.pinChangeSucceeded)))
        
        store.receive(.scannedSuccessfully)
        
        verify(mockStorageManager).setupCompleted.set(true)
        verify(mockEIDInteractionManager).setCAN(can)
        verify(mockEIDInteractionManager).setPIN(oldPIN)
        verify(mockEIDInteractionManager).setNewPIN(newPIN)
        verifyNoMoreInteractions(mockEIDInteractionManager)
    }
    
    func testScanFail() throws {
        let store = TestStore(initialState: SetupCANScan.State(transportPIN: "12345",
                                                               newPIN: "123456",
                                                               can: "111111",
                                                               shared: SharedScan.State()),
                              reducer: SetupCANScan())
        
        store.dependencies.eIDInteractionManager = mockEIDInteractionManager
        store.dependencies.issueTracker = mockIssueTracker
        store.dependencies.previewEIDInteractionManager = mockPreviewEIDInteractionManager
        
        store.send(.scanEvent(.failure(.frameworkError(message: "Fail"))))
        
        store.receive(.error(ScanError.State(errorType: .eIDInteraction(.frameworkError(message: "Fail")), retry: true)))

        verifyNoMoreInteractions(mockEIDInteractionManager)
    }

// TODO: Bring back when we have a cancellation/timeout event from AA2 SDK.
//    func testCancellationOfScanOverlay() {
//        let pin = "111111"
//        let transportPIN = "12345"
//        let can = "333333"
//        let canAndChangedPINCallback = CANAndChangedPINCallback(id: UUID(number: 0)) { _ in }
//        let store = TestStore(
//            initialState: SetupCANScan.State(transportPIN: transportPIN,
//                                             newPIN: pin,
//                                             can: can),
//            reducer: SetupCANScan()
//        )
//
//        let pinCallback: (String, String) -> Void = { _, _ in
//            XCTFail("Callback should not be called")
//        }
//
//        // This is the event that gets published when the user waits too long on the scan overlay or when tapping on the cancel button
//        store.send(.scanEvent(.success(.requestChangedPIN(remainingAttempts: nil, pinCallback: pinCallback)))) {
//            $0.canAndChangedPINCallback = nil
//        }
//
//        store.send(.shared(.startScan))
//
//        store.receive(.shared(.initiateScan))
//    }
}

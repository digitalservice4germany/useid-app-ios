import XCTest
import ComposableArchitecture
import TCACoordinators
import Cuckoo
import Combine
import Analytics

@testable import BundesIdent

class SetupCANCoordinatorTests: XCTestCase {
    func testCANIntroFromImmediateThirdAttemptToCanScan() throws {
        let pin = "123456"
        let transportPIN = "12345"
        let can = "123456"
        let store = TestStore(
            initialState: SetupCANCoordinator.State(pin: pin,
                                                    transportPIN: transportPIN,
                                                    oldTransportPIN: transportPIN,
                                                    tokenURL: demoTokenURL,
                                                    attempt: 0,
                                                    states: [
                                                        .root(.canIntro(CANIntro.State(shouldDismiss: true)))
                                                    ]),
            reducer: SetupCANCoordinator()
        )
        
        store.send(.routeAction(0, action: .canIntro(.showInput(shouldDismiss: true)))) {
            $0.routes.append(.push(.canInput(CANInput.State(pushesToPINEntry: false))))
        }
        
        store.send(.routeAction(1, action: .canInput(.done(can: can, pushesToPINEntry: false)))) {
            $0.can = can
            $0.routes.append(.push(
                .canScan(SetupCANScan.State(transportPIN: transportPIN,
                                            newPIN: pin,
                                            can: can,
                                            shared: .init(startOnAppear: true)))
            ))
        }
        
        store.send(.routeAction(2, action: .canScan(.incorrectCAN))) {
            $0.routes.append(.sheet(.canIncorrectInput(.init())))
        }
    }
    
    func testCANIntroFromThirdAttemptToCanScan() throws {
        let pin = "123456"
        let transportPIN = "12345"
        let can = "123456"
        let store = TestStore(
            initialState: SetupCANCoordinator.State(pin: pin,
                                                    transportPIN: transportPIN,
                                                    oldTransportPIN: transportPIN,
                                                    tokenURL: demoTokenURL,
                                                    attempt: 0,
                                                    states: [
                                                        .root(.canIntro(CANIntro.State(shouldDismiss: true)))
                                                    ]),
            reducer: SetupCANCoordinator()
        )
        
        store.send(.routeAction(0, action: .canIntro(.showInput(shouldDismiss: false)))) {
            $0.routes.append(.push(.canInput(CANInput.State(pushesToPINEntry: true))))
        }
        
        store.send(.routeAction(1, action: .canInput(.done(can: can, pushesToPINEntry: true)))) {
            $0.can = can
            $0.routes.append(.push(
                .canTransportPINInput(SetupTransportPIN.State(enteredPIN: "", digits: 5, attempts: 1))
            ))
        }
        
        let newTransportPIN = "67890"
        store.send(.routeAction(2, action: .canTransportPINInput(SetupTransportPIN.Action.done(transportPIN: newTransportPIN)))) {
            $0.transportPIN = newTransportPIN
            $0.routes.append(.push(
                .canScan(SetupCANScan.State(transportPIN: newTransportPIN,
                                            newPIN: pin,
                                            can: can,
                                            shared: .init(startOnAppear: true)))
            ))
        }
    }
    
    func testSuccessfulScan() {
        let pin = "111111"
        let transportPIN = "12345"
        let can = "333333"
        let store = TestStore(
            initialState: SetupCANCoordinator.State(pin: pin,
                                                    transportPIN: transportPIN,
                                                    oldTransportPIN: transportPIN,
                                                    tokenURL: demoTokenURL,
                                                    attempt: 0,
                                                    states: [
                                                        .root(.canScan(SetupCANScan.State(transportPIN: transportPIN,
                                                                                          newPIN: pin,
                                                                                          can: can)))
                                                    ]),
            reducer: SetupCANCoordinator()
        )
        
        let mockStorageManager = MockStorageManagerType()
        stub(mockStorageManager) {
            $0.setupCompleted.set(any()).thenDoNothing()
        }
        store.dependencies.storageManager = mockStorageManager
        
        store.send(.routeAction(0, action: .canScan(.scannedSuccessfully))) {
            $0.routes.push(.setupCoordinator(SetupCoordinator.State(tokenURL: demoTokenURL,
                                                                    states: [
                                                                        .root(.done(SetupDone.State(tokenURL: demoTokenURL)))
                                                                    ])))
        }
        
        verify(mockStorageManager).setupCompleted.set(true)
    }
}

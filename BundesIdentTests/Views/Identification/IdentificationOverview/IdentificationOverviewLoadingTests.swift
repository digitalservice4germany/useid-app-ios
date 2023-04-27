import Analytics
import XCTest
import ComposableArchitecture
import Cuckoo
import Combine
import TCACoordinators

@testable import BundesIdent

final class IdentificationOverviewLoadingTests: XCTestCase {
    
    func testOnAppearCallsIdentifiy() {
        let store = TestStore(initialState: IdentificationOverviewLoading.State(), reducer: IdentificationOverviewLoading())
        store.send(.onAppear) {
            $0.onAppearCalled = true
        }
        store.receive(.identify)
    }
    
    func testOnAppearWhenAlreadyCallsIsIgnored() {
        let store = TestStore(initialState: IdentificationOverviewLoading.State(onAppearCalled: true), reducer: IdentificationOverviewLoading())
        store.send(.onAppear)
    }
    
    func testReceiveRequestConfirmationRetrievesCertificateDescription() {
        let request = AuthenticationRequest.preview
        let store = TestStore(initialState: IdentificationOverviewLoading.State(), reducer: IdentificationOverviewLoading())
        
        let mockEIDInteractionManager = MockEIDInteractionManagerType()
        stub(mockEIDInteractionManager) {
            $0.retrieveCertificateDescription().thenDoNothing()
        }
        store.dependencies.eIDInteractionManager = mockEIDInteractionManager
        
        store.send(.eIDInteractionEvent(.success(.authenticationRequestConfirmationRequested(request)))) {
            $0.authenticationRequest = request
        }
        
        verify(mockEIDInteractionManager).retrieveCertificateDescription()
    }
    
    func testReceiveCertificateCallsDone() {
        let request = AuthenticationRequest.preview
        let store = TestStore(initialState: IdentificationOverviewLoading.State(authenticationRequest: .preview), reducer: IdentificationOverviewLoading())
        
        let certificateDescription = CertificateDescription.preview
        store.send(.eIDInteractionEvent(.success(.certificateDescriptionRetrieved(certificateDescription))))
        store.receive(.done(request, certificateDescription))
    }
}

import Foundation
import CombineSchedulers
import Combine

struct MockIDInteractionManager: IDInteractionManagerType {

    func changePIN(messages: ScanOverlayMessages) -> EIDInteractionPublisher {
        let subject = PassthroughSubject<EIDInteractionEvent, IDCardInteractionError>()
        subject.send(completion: .failure(.frameworkError(message: "Not implemented")))
        return subject.eraseToAnyPublisher()
    }
    
    func identify(tokenURL: URL, messages: ScanOverlayMessages) -> EIDInteractionPublisher {
        let subject = PassthroughSubject<EIDInteractionEvent, IDCardInteractionError>()
        subject.send(completion: .failure(.frameworkError(message: "Not implemented")))
        return subject.eraseToAnyPublisher()
    }
    
    func setPIN(_ pin: String) {
        // not implemented
    }

    func setNewPIN(_ pin: String) {
        // not implemented
    }

    func setCAN(_ can: String) {
        // not implemented
    }

    func retrieveCertificateDescription() {
        // not implemented
    }
    
    func acceptAccessRights() {
        // not implemented
    }
    
    func interrupt() {
        // not implemented
    }
    
    func cancel() {
        // not implemented
    }
}

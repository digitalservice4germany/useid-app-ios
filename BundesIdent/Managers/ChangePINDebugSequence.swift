import Combine
import Foundation

#if PREVIEW

enum ChangePINDebugSequence: Identifiable, Equatable {
    case cancelPINScan
    case cancelCANScan
    case changePINSuccessfully
    case runPINError(remainingAttempts: Int, cancelAction: CancelAction)
    case runNFCError
    case runCardSuspended
    case runCardDeactivated
    case runCardBlocked
    case runCANError
    
    var id: String {
        switch self {
        case .cancelPINScan: return "cancel"
        case .cancelCANScan: return "cancel"
        case .changePINSuccessfully: return "changePINSuccessfully"
        case .runPINError(let remainingAttempts, _): return "runPINError (\(remainingAttempts))"
        case .runNFCError: return "runNFCError"
        case .runCardSuspended: return "runCardSuspended"
        case .runCardDeactivated: return "runCardDeactivated"
        case .runCardBlocked: return "runCardBlocked"
        case .runCANError: return "runCANError"
        }
    }
    
    static func defaultActions(card: Card) -> [ChangePINDebugSequence] {
        var actions: [ChangePINDebugSequence] = [
            .cancelPINScan,
            .changePINSuccessfully,
            .runCardSuspended,
            .runNFCError,
            .runCardDeactivated,
            .runCardBlocked
        ]
        
        if card.remainingAttempts >= 0 {
            actions.append(.runPINError(remainingAttempts: card.remainingAttempts, cancelAction: .pin))
        }
        
        return actions
    }
    
    func run(card: inout Card, subject: PassthroughSubject<EIDInteractionEvent, IDCardInteractionError>) -> [ChangePINDebugSequence] {
        switch self {
        case .cancelPINScan:
            subject.send(.cardInteractionComplete)
            subject.send(.requestChangedPIN(remainingAttempts: nil, pinCallback: { _, _ in
                subject.send(.requestCardInsertion({ _ in }))
            }))
            return ChangePINDebugSequence.defaultActions(card: card)
        case .cancelCANScan:
            subject.send(.cardInteractionComplete)
            subject.send(.requestPINAndCAN({ _, _ in
                subject.send(.requestCardInsertion({ _ in }))
            }))
            return [
                .cancelCANScan,
                .changePINSuccessfully,
                .runCANError,
                .runNFCError,
                .runCardDeactivated,
                .runCardBlocked
            ]
        case .changePINSuccessfully:
            card.remainingAttempts = 3
            subject.send(.cardRecognized)
            subject.send(.cardInteractionComplete)
            subject.send(.processCompletedSuccessfullyWithoutRedirect)
            subject.send(completion: .finished)
            return []
        case .runPINError(remainingAttempts: let remainingAttempts, cancelAction: let cancelAction):
            
            let secondCallback = {
                subject.send(.cardRemoved)
                subject.send(.requestCardInsertion({ _ in }))
            }
            
            card.remainingAttempts = remainingAttempts - 1
            
            let firstCallback = { [card] in
                subject.send(.cardRemoved)
                subject.send(.requestCardInsertion({ _ in }))
                subject.send(.cardRecognized)
                subject.send(.cardInteractionComplete)
                
                if card.remainingAttempts >= 2 {
                    subject.send(.requestChangedPIN(remainingAttempts: card.remainingAttempts, pinCallback: { _, _ in secondCallback() }))
                } else if card.remainingAttempts == 1 {
                    subject.send(.requestCANAndChangedPIN(pinCallback: { _, _, _ in secondCallback() }))
                } else {
                    subject.send(completion: .failure(.cardBlocked))
                }
            }
            
            subject.send(.cardRecognized)
            subject.send(.cardInteractionComplete)
            
            let cancelDebugSequence: ChangePINDebugSequence
            switch cancelAction {
            case .pin: cancelDebugSequence = .cancelPINScan
            case .can: cancelDebugSequence = .cancelCANScan
            }
            
            if card.remainingAttempts >= 2 {
                subject.send(.requestChangedPIN(remainingAttempts: remainingAttempts, pinCallback: { _, _ in firstCallback() }))
                return [.changePINSuccessfully, .runPINError(remainingAttempts: card.remainingAttempts, cancelAction: cancelAction), cancelDebugSequence]
            } else if card.remainingAttempts == 1 {
                subject.send(.requestCANAndChangedPIN(pinCallback: { _, _, _ in }))
                return [.changePINSuccessfully, .runPINError(remainingAttempts: card.remainingAttempts, cancelAction: cancelAction), .runCANError, cancelDebugSequence]
            } else {
                subject.send(completion: .failure(.cardBlocked))
                return []
            }
        case .runNFCError:
            subject.send(completion: .failure(.processFailed(resultCode: .INTERNAL_ERROR, redirectURL: nil, resultMinor: nil)))
            return ChangePINDebugSequence.defaultActions(card: card)
        case .runCardSuspended:
            card.remainingAttempts = 1
            subject.send(.requestCANAndChangedPIN(pinCallback: { _, _, _ in }))
            return [.cancelCANScan, .changePINSuccessfully, .runCANError, .runPINError(remainingAttempts: card.remainingAttempts, cancelAction: .can)]
        case .runCardDeactivated:
            subject.send(.cardRecognized)
            subject.send(.cardInteractionComplete)
            subject.send(completion: .failure(.cardDeactivated))
            return []
        case .runCardBlocked:
            subject.send(.cardRecognized)
            subject.send(.cardInteractionComplete)
            subject.send(completion: .failure(.cardBlocked))
            return []
        case .runCANError:
            subject.send(.cardRecognized)
            subject.send(.cardInteractionComplete)
            subject.send(.requestCANAndChangedPIN { _, _, _ in
                subject.send(.requestCardInsertion { _ in })
            })
            subject.send(.cardRemoved)
            return [.cancelCANScan, .changePINSuccessfully, .runCANError, .runPINError(remainingAttempts: card.remainingAttempts, cancelAction: .can)]
        }
    }
}

#endif

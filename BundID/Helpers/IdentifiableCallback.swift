import Foundation

struct IdentifiableCallback<Parameter>: Identifiable, Equatable {
    
    let id: UUID
    private let callback: (Parameter) -> Void
    
    private var called: Bool = false
    
    init(id: UUID, callback: @escaping (Parameter) -> Void) {
        self.id = id
        self.callback = callback
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
    
    mutating func callAsFunction(_ value: Parameter) {
        guard !called else {
            fatalError("Callback already called. Aborting.")
        }
        
        called = true
        callback(value)
    }
}

import SwiftUI
import ComposableArchitecture

struct DialogButtons<Action>: View {
    
    var store: Store<Void, Action>
    var secondaryButtonConfiguration: ButtonConfiguration?
    var primaryButtonConfiguration: ButtonConfiguration?
    
    struct ButtonConfiguration {
        let title: String
        let action: Action
    }
    
    init(store: Store<Void, Action>, secondary: ButtonConfiguration? = nil, primary: ButtonConfiguration?) {
        self.store = store
        secondaryButtonConfiguration = secondary
        primaryButtonConfiguration = primary
    }
    
    var body: some View {
        VStack {
            if let primaryButtonConfiguration {
                Button(primaryButtonConfiguration.title,
                       action: { ViewStore(store).send(primaryButtonConfiguration.action) })
                    .buttonStyle(BundButtonStyle(isPrimary: true))
            }
            if let secondaryButtonConfiguration {
                Button(secondaryButtonConfiguration.title,
                       action: { ViewStore(store).send(secondaryButtonConfiguration.action) })
                    .buttonStyle(BundButtonStyle(isPrimary: false))
            }
        }
        .padding([.leading, .bottom, .trailing])
        .background(Color.white)
    }
}

enum DialogButtonsPreviewAction {
    case secondary
    case primary
}

struct DialogButtons_Previews: PreviewProvider {
    static var previews: some View {
        DialogButtons<DialogButtonsPreviewAction>(store: .empty,
                                                  secondary: nil,
                                                  primary: .init(title: "Primary", action: .primary))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Primary")
        DialogButtons<DialogButtonsPreviewAction>(store: .empty,
                                                  secondary: .init(title: "Secondary", action: .secondary),
                                                  primary: nil)
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Secondary")
        DialogButtons<DialogButtonsPreviewAction>(store: .empty,
                                                  secondary: .init(title: "Secondary", action: .secondary),
                                                  primary: .init(title: "Primary", action: .primary))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Both")
    }
}

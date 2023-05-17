import SwiftUI
import MarkdownUI

extension Theme {

    static let bund = Theme
        .basic
        .text {
            FontProperties.bodyLRegular
            ForegroundColor(.blackish)
        }
        .link {
            FontWeight(.bold)
            ForegroundColor(.accentColor)
            UnderlineStyle(.init(pattern: .solid, color: .accentColor))
        }
        .bulletedListMarker { _ in
            Text("• ")
                .relativeFrame(minWidth: .em(1.0), alignment: .trailing)
        }
        .listItem {
            $0.label.markdownMargin(top: .em(0.7))
        }
        .paragraph {
            $0.label.markdownMargin(top: .zero, bottom: .em(1.4))
        }
}

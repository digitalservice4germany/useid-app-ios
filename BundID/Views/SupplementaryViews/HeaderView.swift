import SwiftUI

struct ImageMeta {
    let name: String
    let labelKey: String?
    let maxHeight: CGFloat?
    
    init(name: String, labelKey: String? = nil, maxHeight: CGFloat? = nil) {
        self.name = name
        self.labelKey = labelKey
        self.maxHeight = maxHeight
    }
    
    init(asset: ImageAsset, labelKey: String? = nil, maxHeight: CGFloat? = nil) {
        self.name = asset.name
        self.labelKey = labelKey
        self.maxHeight = maxHeight
    }
}

struct LinkMeta {
    let title: String
    let url: URL
}

struct HeaderView: View {
    
    var title: String
    var message: String?
    var imageMeta: ImageMeta?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.bundLargeTitle)
                    .foregroundColor(.blackish)
                    .padding(.bottom, 24)
                if let message = message {
                    Text(attributed(message: message))
                        .font(.bundBody)
                        .foregroundColor(.blackish)
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal)
            if let imageMeta = imageMeta {
                imageMeta.image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: imageMeta.maxHeight)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
            }
        }
    }
    
    func attributed(message: String) -> AttributedString {
        (try? AttributedString(markdown: message,
                              options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(message)
    }
}

extension ImageMeta {
    var image: Image {
        if let labelKey = labelKey {
            return Image(name, label: Text(labelKey))
        } else {
            return Image(decorative: name)
        }
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView(title: L10n.FirstTimeUser.Intro.title,
                   message: L10n.FirstTimeUser.Intro.body,
                   imageMeta: ImageMeta(asset: Asset.pinBrief))
        .previewLayout(.sizeThatFits)
    }
}

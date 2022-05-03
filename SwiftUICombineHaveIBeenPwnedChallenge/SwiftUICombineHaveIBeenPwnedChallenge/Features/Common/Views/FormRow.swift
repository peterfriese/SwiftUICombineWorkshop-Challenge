import SwiftUI

struct FormRow<Content> : View where Content : View {
    private var content: () -> Content
    private var image: Image

    @inlinable public init(systemImage name: String, @ViewBuilder content: @escaping () -> Content) {
        self.image = Image(systemName: name)
        self.content = content
    }
    
    var body: some View {
        HStack {
            image
            content()
        }
        .padding(.vertical, 6)
        .background(Divider(), alignment: .bottom)
        .padding(.bottom, 8)
    }
}

struct FormRow_Previews: PreviewProvider {
    static var previews: some View {
        FormRow(systemImage: "at") {
            Text("Hello")
            Spacer()
        }
        .previewLayout(.sizeThatFits)
    }
}

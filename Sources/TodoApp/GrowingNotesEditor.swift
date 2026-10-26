import SwiftUI

struct GrowingNotesEditor: View {
    @Binding var text: String
    @State private var contentHeight: CGFloat = 22
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Match the native editor's line-fragment padding, including trailing blank lines.
            Text(text.isEmpty ? " " : text + " ")
                .font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background {
                    GeometryReader { geometry in
                        Color.clear.onAppear { contentHeight = geometry.size.height }
                            .onChange(of: geometry.size.height) { contentHeight = geometry.size.height }
                    }
                }.hidden()
            if text.isEmpty {
                Text(L("备注")).foregroundStyle(.tertiary).padding(.leading, 5).padding(.top, 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: min(152, max(22, contentHeight)), alignment: .topLeading)
        .overlay {
            TextEditor(text: $text).font(.system(size: 13))
                .scrollContentBackground(.hidden).accessibilityLabel(L("描述"))
        }
        .clipped()
    }
}

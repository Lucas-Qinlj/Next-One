import SwiftUI

struct Toast: Identifiable {
    enum Kind { case success, error, warning }
    let id = UUID()
    let message: String
    let kind: Kind
}

struct ToastView: View {
    let toast: Toast
    let dismiss: () -> Void
    private var color: Color {
        switch toast.kind { case .success: return .green; case .error: return .red; case .warning: return .yellow }
    }
    private var symbol: String {
        switch toast.kind {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    private var category: String {
        switch toast.kind { case .success: return "成功"; case .error: return "错误"; case .warning: return "提醒" }
    }
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(color)
                .accessibilityLabel(category)
            Text(toast.message).font(.system(size: 13)).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            IconButton(name: "xmark", title: "关闭提示", action: dismiss)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.10)).allowsHitTesting(false))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.45)).allowsHitTesting(false))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
    }
}

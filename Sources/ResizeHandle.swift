import SwiftUI

struct ResizeHandle: View {
    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .padding(4)
        }
    }
}

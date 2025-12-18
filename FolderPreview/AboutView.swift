
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
            
            Text("Folder Preview")
                .font(.title)
                .bold()
            
            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("© 2025 Folder Preview App")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

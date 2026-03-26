
import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Image(systemName: "folder.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.blue)
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
                .shadow(radius: 5)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 100, height: 100)
                )
            
            VStack(spacing: 8) {
                Text("Folder Preview")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Quick Look Extension for Previewing Folders")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to Use the Extension?")
                        .font(.headline)
                    Text("Press spacebar or ⌘ + Y to quick look folders in Finder.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Quick Look Extension")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Open [System Settings](x-apple.systempreferences:com.apple.preferences).")
                            .foregroundColor(.blue)
                        Text("2. Scroll down to the \"Extensions\" section and click the info button in \"Folder Preview\".")
                        Text("3. Select \"Folder Preview\" extension.")
                        Text("4. Select \"Archive Preview\" if you want to preview archive files like .zip, .7z, and .rar.")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 40)
        .frame(minWidth: 500, minHeight: 400)
    }
}

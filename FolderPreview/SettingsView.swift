
import SwiftUI

struct SettingsView: View {
    // MUST MATCH THE APP GROUP NAME in Xcode -> Signing & Capabilities
    static let appGroup = "group.com.example.FolderPreview"
    
    @AppStorage("viewStyle", store: UserDefaults(suiteName: appGroup)) private var viewStyle: String = "list"
    @AppStorage("rowHeight", store: UserDefaults(suiteName: appGroup)) private var rowHeight: String = "small"
    @AppStorage("showPathBar", store: UserDefaults(suiteName: appGroup)) private var showPathBar: Bool = true
    
    @AppStorage("showHiddenFiles", store: UserDefaults(suiteName: appGroup)) private var showHiddenFiles: Bool = false
    @AppStorage("keepFoldersOnTop", store: UserDefaults(suiteName: appGroup)) private var keepFoldersOnTop: Bool = true
    @AppStorage("expandChildFolders", store: UserDefaults(suiteName: appGroup)) private var expandChildFolders: Bool = true
    @AppStorage("limitFolderDepth", store: UserDefaults(suiteName: appGroup)) private var limitFolderDepth: Bool = true
    @AppStorage("folderDepth", store: UserDefaults(suiteName: appGroup)) private var folderDepth: Int = 7
    @AppStorage("isExtensionEnabled", store: UserDefaults(suiteName: appGroup)) private var isExtensionEnabled: Bool = true
    
    @State private var isInstructionsExpanded: Bool = false
    
    var body: some View {
        Form {
            Section {
                DisclosureGroup(isExpanded: $isInstructionsExpanded) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("How to Use the Extension?")
                            .font(.headline)
                        Text("Press spacebar or ⌘ + Y to quick look folders in Finder.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 5)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enable Quick Look Extension")
                            .font(.headline)
                        
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            Link("1. Open System Settings.", destination: url)
                        } else {
                            Text("1. Open System Settings.")
                        }
                        
                        Text("2. Scroll down to the \"Extensions\" section and click the info button in \"Folder Preview\".")
                        Text("3. Select \"Folder Preview\" extension.")
                        Text("4. Select \"Archive Preview\" if you want to preview archive files like .zip, .7z, and .rar.")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 5)
                } label: {
                    Text("Instructions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                isInstructionsExpanded.toggle()
                            }
                        }
                }
            }
            
            Section("General") {
                Toggle("Enable Folder Preview", isOn: $isExtensionEnabled)
            }
            
            Section("Appearance") {
                Picker("View", selection: $viewStyle) {
                    Text("as List").tag("list")
                    Text("as Icons").tag("icons")
                }
                .pickerStyle(.inline)
                
                Picker("Row height", selection: $rowHeight) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.inline)
                
                Toggle("Show Path Bar", isOn: $showPathBar)
            }
            
            Section("Behaviors") {
                Toggle("Show hidden files", isOn: $showHiddenFiles)
                Toggle("Keep folders on top", isOn: $keepFoldersOnTop)
                Toggle("Expand all child folders", isOn: $expandChildFolders)
                
                
                Toggle("Limit folder depth", isOn: $limitFolderDepth)
                
                if limitFolderDepth {
                    HStack {
                        Text("Max Depth")
                        Spacer()
                        Stepper("", value: $folderDepth, in: 1...20)
                        Text("\(folderDepth)")
                            .frame(width: 20)
                    }
                }
                
                Text(limitFolderDepth ? "For folders with deep hierarchy, it takes much longer before result shown. Therefore the extension imposes a depth limit." : "Warning: Disabling depth limit may cause performance issues or hang the preview for very deep folder structures.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
    }
}

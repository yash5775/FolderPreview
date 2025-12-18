
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
    @AppStorage("folderDepth", store: UserDefaults(suiteName: appGroup)) private var folderDepth: Int = 7
    
    var body: some View {
        Form {
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
                
                HStack {
                    Text("Folder depth")
                    Spacer()
                    Stepper("", value: $folderDepth, in: 1...20)
                    Text("\(folderDepth)")
                        .frame(width: 20)
                }
                Text("For folders with deep hierarchy, it takes much longer before result shown. Therefore the extension imposes a depth limit.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
    }
}


import Cocoa
import Quartz
import SwiftUI

class PreviewViewController: NSViewController, QLPreviewingController {

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
        // Do any additional setup after loading the view.
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let hostingController = NSHostingController(rootView: FolderPreviewView(folderURL: url))
        
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

}

struct FolderPreviewView: View {
    let folderURL: URL
    
    // MUST MATCH THE APP GROUP NAME
    static let appGroup = "group.com.example.FolderPreview"
    
    @AppStorage("viewStyle", store: UserDefaults(suiteName: appGroup)) private var viewStyle: String = "list"
    @AppStorage("rowHeight", store: UserDefaults(suiteName: appGroup)) private var rowHeight: String = "small"
    @AppStorage("showPathBar", store: UserDefaults(suiteName: appGroup)) private var showPathBar: Bool = true
    
    var rowHeightValue: CGFloat {
        switch rowHeight {
        case "small": return 22
        case "large": return 40
        default: return 30 // medium
        }
    }
    
    @AppStorage("showHiddenFiles", store: UserDefaults(suiteName: appGroup)) private var showHiddenFiles: Bool = false
    @AppStorage("keepFoldersOnTop", store: UserDefaults(suiteName: appGroup)) private var keepFoldersOnTop: Bool = true
    @AppStorage("expandChildFolders", store: UserDefaults(suiteName: appGroup)) private var expandChildFolders: Bool = true
    @AppStorage("folderDepth", store: UserDefaults(suiteName: appGroup)) private var folderDepth: Int = 7
    
    @State private var items: [FileItem] = []
    @State private var sortOrder: [KeyPathComparator<FileItem>] = [
        .init(\.url.lastPathComponent, order: .forward)
    ]
    
    struct FileItem: Identifiable, Hashable {
        let id: URL
        let url: URL
        var children: [FileItem]?
        
        let modificationDate: Date
        let fileSize: Int64?
        let kind: String
        let isDirectory: Bool
        
        var sizeForSorting: Int64 {
            fileSize ?? 0
        }

        var fileSizeString: String {
            guard let size = fileSize else { return "--" }
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        
        var dateString: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: modificationDate)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            mainContentView
            
            if showPathBar {
                Divider()
                bottomBar
            }
        }
        .onAppear {
            loadContents()
        }
        .onChange(of: showHiddenFiles) { _, _ in loadContents() }
        .onChange(of: keepFoldersOnTop) { _, _ in loadContents() }
        .onChange(of: expandChildFolders) { _, _ in 
            loadContents() 
        }
        .onChange(of: folderDepth) { _, _ in loadContents() }
        .onChange(of: sortOrder) { _, _ in
            applySort()
        }
        .background(
             Group {
                 if expandChildFolders {
                     AutoExpandView { }
                         .frame(width: 0, height: 0)
                 }
             }
        )
    }
    
    var headerView: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: folderURL.path))
                .resizable()
                .frame(width: 32, height: 32)
            Text(folderURL.lastPathComponent)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    var bottomBar: some View {
        VStack(spacing: 8) {
            // Path Breadcrumbs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(pathComponents, id: \.path) { component in
                        HStack(spacing: 2) {
                            if component.name != "/" {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                Image(nsImage: component.icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text(component.name)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 24)
            
            // Status Line (Size, Count)
            Text(statusDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    struct PathComponent {
        let name: String
        let path: String
        let icon: NSImage
    }
    
    var pathComponents: [PathComponent] {
        var components: [PathComponent] = []
        let values = folderURL.pathComponents
        var currentPath = ""
        
        for (index, component) in values.enumerated() {
            if component == "/" && index == 0 {
                currentPath = "/"
                let icon = NSWorkspace.shared.icon(forFile: "/")
                components.append(PathComponent(name: "Macintosh HD", path: "/", icon: icon))
            } else if component != "/" {
                if currentPath == "/" {
                    currentPath += component
                } else {
                    currentPath += "/" + component
                }
                let icon = NSWorkspace.shared.icon(forFile: currentPath)
                components.append(PathComponent(name: component, path: currentPath, icon: icon))
            }
        }
        return components
    }
    
    var statusDescription: String {
        let itemsCount = items.count
        let sizeString = ByteCountFormatter.string(fromByteCount: totalFolderSize, countStyle: .file)
        return "\(sizeString), \(itemsCount) items"
    }
    
    @ViewBuilder
    var mainContentView: some View {
        if items.isEmpty {
             VStack {
                Spacer()
                Text("Folder is empty")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxHeight: .infinity)
        } else {
            if viewStyle == "icons" {
                iconGridView
            } else {
                columnsTableView
            }
        }
    }
    
    var iconGridView: some View {
        ScrollView {
             LazyVGrid(columns: [GridItem(.adaptive(minimum: rowHeightValue * 2))], spacing: 20) {
                ForEach(items, id: \.self) { item in
                    VStack {
                        ThumbnailView(url: item.url)
                            .frame(width: rowHeightValue * 1.5, height: rowHeightValue * 1.5)
                        Text(item.url.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Text(item.fileSizeString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    var columnsTableView: some View {
        Table(items, children: \.children, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.url.lastPathComponent) { item in
                HStack {
                    ThumbnailView(url: item.url)
                        // Use rowHeightValue to scale the thumbnail in list view, min 16
                        .frame(width: max(16, rowHeightValue * 0.8), height: max(16, rowHeightValue * 0.8))
                    Text(item.url.lastPathComponent)
                }
            }
            .width(min: 200, ideal: 300, max: .infinity)
            
            TableColumn("Date Modified", value: \.modificationDate) { item in
                Text(item.dateString)
            }
            .width(min: 140, ideal: 160, max: 180)
            
            TableColumn("Size", value: \.sizeForSorting) { item in
                Text(item.fileSizeString)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 80, max: 100)
            
            TableColumn("Kind", value: \.kind) { item in
                Text(item.kind)
            }
            .width(min: 100, ideal: 120, max: 150)
        }
        .onChange(of: sortOrder) { _, _ in
            applySort()
        }
        .background(
             Group {
                 if expandChildFolders {
                     AutoExpandView { }
                         .frame(width: 0, height: 0)
                 }
             }
        )
    }
    

    
    @State private var totalFolderSize: Int64 = 0
    
    private func loadContents() {
        items = fetchItems(at: folderURL, currentDepth: 1)
        applySort()
        
        // Asynchronously calculate deep size
        DispatchQueue.global(qos: .utility).async {
            let size = calculateDeepSize(at: folderURL)
            DispatchQueue.main.async {
                self.totalFolderSize = size
            }
        }
    }
    
    private func calculateDeepSize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) else { return 0 }
        
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let rs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let s = rs.fileSize {
                total += Int64(s)
            }
        }
        return total
    }
    
    private func applySort() {
        items = sortItems(items)
    }
    
    private func sortItems(_ itemsToSort: [FileItem]) -> [FileItem] {
        var sorted = itemsToSort
        if keepFoldersOnTop {
            var folders = sorted.filter { $0.isDirectory }
            var files = sorted.filter { !$0.isDirectory }
            
            folders.sort(using: sortOrder)
            files.sort(using: sortOrder)
            
            // Recursively sort children of folders
            // Note: Since FileItem is a struct, we need to reconstruct if we modify children.
            // But wait, children are part of FileItem. 
            // We already sorted children during fetch if we use recursion there.
            // But if we change sort order effectively later, we need to update children too.
            // This is complex for structs. 
            // For now, let's assume fetch sorts initially. 
            // Re-sorting deep structure on column click is expensive but necessary for consistency.
            // Let's implement deep sort.
            
            folders = folders.map { folder in
                var newFolder = folder
                if let kids = folder.children {
                    newFolder.children = sortItems(kids)
                }
                return newFolder
            }
            
            return folders + files
        } else {
            // Standard sort
            sorted.sort(using: sortOrder)
             
             // Deep sort
             sorted = sorted.map { item in
                var newItem = item
                if let kids = item.children {
                    newItem.children = sortItems(kids)
                }
                return newItem
            }
            
            return sorted
        }
    }
    
    private func fetchItems(at url: URL, currentDepth: Int) -> [FileItem] {
        do {
            var options: FileManager.DirectoryEnumerationOptions = []
            if !showHiddenFiles {
                options.insert(.skipsHiddenFiles)
            }
            
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .localizedTypeDescriptionKey]
            
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: options)
            
            return contents.compactMap { fileURL -> FileItem? in
                guard let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) else { return nil }
                
                let isDir = values.isDirectory ?? false
                let date = values.contentModificationDate ?? Date()
                var size = values.fileSize.map { Int64($0) }
                let kind = values.localizedTypeDescription ?? (isDir ? "Folder" : "File")
                
                if isDir {
                    // Start with 0 for folders initially found
                    // Note: Calculating recursive size for EVERY folder in the view synchronously 
                    // is very expensive. For a smoother experience, we might want to do this async.
                    // However, for immediate valid data requested by user:
                    size = calculateDeepSize(at: fileURL)
                }
                
                var children: [FileItem]? = nil
                 if isDir && currentDepth < folderDepth {
                    let childItems = fetchItems(at: fileURL, currentDepth: currentDepth + 1)
                    // Apply sort to children immediately
                    children = sortItems(childItems)
                }
                
                return FileItem(
                    id: fileURL,
                    url: fileURL,
                    children: children,
                    modificationDate: date,
                    fileSize: size,
                    kind: kind,
                    isDirectory: isDir
                )
            }
        } catch {
            print("Error loading folder contents: \(error)")
            return []
        }
    }
}

import QuickLookThumbnailing

struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        // 1. Try direct loading for common image types (faster/simpler if sandbox allows)
        let imageExtensions = ["png", "jpg", "jpeg", "tiff", "gif", "bmp", "ico", "icns"]
        if imageExtensions.contains(url.pathExtension.lowercased()) {
            // Run on background to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                if let directImage = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.image = directImage
                    }
                    return
                }
                // If direct load fails, fall through to QL
                self.generateQLThumbnail()
            }
        } else {
            generateQLThumbnail()
        }
    }
    
    private func generateQLThumbnail() {
        let size = CGSize(width: 128, height: 128)
        let scale = 2.0 // Default to 2.0 if screen is ni
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { (thumbnail, error) in
            if let thumbnail = thumbnail {
                DispatchQueue.main.async {
                    self.image = thumbnail.nsImage
                }
            } else if let error = error {
                print("Thumbnail generation error: \(error)")
            }
        }
    }
}

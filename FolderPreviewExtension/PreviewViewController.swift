
import Cocoa
import Quartz
import SwiftUI
import UniformTypeIdentifiers
import Compression

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

struct ZipMetadata: Hashable {
    let localHeaderOffset: UInt64
    let compressedSize: Int64
    let uncompressedSize: Int64
    let compressionMethod: UInt16 // 0 = Store, 8 = Deflate
    let sourceZipURL: URL
}

struct FileItem: Identifiable, Hashable {
    let id: URL
    let url: URL
    var children: [FileItem]?
    var icon: NSImage? = nil // Cache for Zip items or specific icons
    var zipMetadata: ZipMetadata? = nil // For extracting thumbnails
    
    let modificationDate: Date
    let fileSize: Int64?
    let kind: String
    let isDirectory: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
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
    @AppStorage("limitFolderDepth", store: UserDefaults(suiteName: appGroup)) private var limitFolderDepth: Bool = true
    @AppStorage("folderDepth", store: UserDefaults(suiteName: appGroup)) private var folderDepth: Int = 7
    


    @State private var items: [FileItem] = []
    @State private var sortOrder: [KeyPathComparator<FileItem>] = [
        .init(\.url.lastPathComponent, order: .forward)
    ]
    
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
                        ThumbnailView(item: item)
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
                    ThumbnailView(item: item)
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
        // Reset state
        self.items = []
        
        let isDir = (try? folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        
        if isDir {
            items = fetchItems(at: folderURL, currentDepth: 1)
            applySort()
            
            // Asynchronously calculate deep size
            DispatchQueue.global(qos: .utility).async {
                let size = calculateDeepSize(at: folderURL)
                DispatchQueue.main.async {
                    self.totalFolderSize = size
                }
            }
        } else if folderURL.pathExtension.lowercased() == "zip" {
            // Handle Zip File
            DispatchQueue.global(qos: .userInitiated).async {
                let zipItems = fetchZipItems(at: folderURL)
                DispatchQueue.main.async {
                    self.items = zipItems
                    self.totalFolderSize = zipItems.reduce(0) { $0 + ($1.fileSize ?? 0) }
                }
            }
        }
    }
    
    private func fetchZipItems(at url: URL) -> [FileItem] {
        var entries: [(path: String, isDir: Bool, date: Date, size: Int64, zipMeta: ZipMetadata?)] = []
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            
            let fileSize = try fileHandle.seekToEnd()
            let searchLimit = min(fileSize, 65557)
            try fileHandle.seek(toOffset: fileSize - searchLimit)
            let footerData = fileHandle.readDataToEndOfFile()
            
            guard let eocdRange = footerData.range(of: Data([0x50, 0x4b, 0x05, 0x06]), options: .backwards) else { return [] }
            let eocdStart = eocdRange.lowerBound
            if eocdStart + 20 > footerData.count { return [] }
            
            let cdOffsetData = footerData.subdata(in: eocdStart + 16 ..< eocdStart + 20)
            let cdOffset = cdOffsetData.withUnsafeBytes { $0.load(as: UInt32.self) }
            let cdCountData = footerData.subdata(in: eocdStart + 10 ..< eocdStart + 12)
            let cdCount = cdCountData.withUnsafeBytes { $0.load(as: UInt16.self) }
            
            try fileHandle.seek(toOffset: UInt64(cdOffset))
            
            for _ in 0..<cdCount {
                let signatureData = fileHandle.readData(ofLength: 4)
                if signatureData != Data([0x50, 0x4b, 0x01, 0x02]) { break }
                let headerData = fileHandle.readData(ofLength: 42)
                
                // CD Offsets:
                // 10-11: Compression Method
                // 12-13: Last Mod Time
                // 14-15: Last Mod Date
                // 20-23: Compressed Size
                // 24-27: Uncompressed Size
                // 28-29: Filename Len
                // 30-31: Extra Field Len
                // 32-33: File Comment Len
                // 42-45: Relative Offset of Local Header
                
                // headerData[0] is Byte 4 (Version Made By) relative to Signature (0-3).
                // So Subtract 4 from absolute offsets.
                
                let compressionMethod = headerData.subdata(in: 10-4..<12-4).withUnsafeBytes { $0.load(as: UInt16.self) }
                let timeData = headerData.subdata(in: 12-4..<14-4).withUnsafeBytes { $0.load(as: UInt16.self) }
                let dateData = headerData.subdata(in: 14-4..<16-4).withUnsafeBytes { $0.load(as: UInt16.self) }
                let compressedSize = headerData.subdata(in: 20-4..<24-4).withUnsafeBytes { $0.load(as: UInt32.self) }
                let uncompressedSize = headerData.subdata(in: 24-4..<28-4).withUnsafeBytes { $0.load(as: UInt32.self) }
                let filenameLen = headerData.subdata(in: 28-4..<30-4).withUnsafeBytes { $0.load(as: UInt16.self) }
                let extraFieldLen = headerData.subdata(in: 30-4..<32-4).withUnsafeBytes { $0.load(as: UInt16.self) }
                let commentLen = headerData.subdata(in: 32-4..<34-4).withUnsafeBytes { $0.load(as: UInt16.self) }
                let localHeaderOffset = headerData.subdata(in: 42-4..<46-4).withUnsafeBytes { $0.load(as: UInt32.self) }
                
                let filenameData = fileHandle.readData(ofLength: Int(filenameLen))
                let filename = String(data: filenameData, encoding: .utf8) ?? "Unknown"
                
                let date = parseMSDOSDate(time: timeData, date: dateData)
                
                try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(extraFieldLen) + UInt64(commentLen))
                
                // Filter Junk
                if !filename.contains("__MACOSX") && !filename.hasPrefix(".") && !filename.contains("/.") {
                    let isDir = filename.hasSuffix("/")
                    // Clean path: remove trailing slash
                    let cleanPath = isDir ? String(filename.dropLast()) : filename
                    
                    let meta = ZipMetadata(
                        localHeaderOffset: UInt64(localHeaderOffset),
                        compressedSize: Int64(compressedSize),
                        uncompressedSize: Int64(uncompressedSize),
                        compressionMethod: compressionMethod,
                        sourceZipURL: url
                    )
                    
                    entries.append((cleanPath, isDir, date, Int64(uncompressedSize), meta))
                }
            }
        } catch {
            print("Zip Parse Error: \(error)")
        }
        
        let rootItems = buildTree(from: entries)
        
        // Smart Unwrapping
        if rootItems.count == 1, let root = rootItems.first, root.isDirectory, let children = root.children {
            return children
        }
        
        return rootItems
    }
    
    private func buildTree(from entries: [(path: String, isDir: Bool, date: Date, size: Int64, zipMeta: ZipMetadata?)]) -> [FileItem] {
        class Node {
            var name: String
            var children: [String: Node] = [:]
            var isDir: Bool = true
            var date: Date = Date()
            var size: Int64 = 0
            var zipMeta: ZipMetadata? = nil
            
            init(name: String) { self.name = name }
            
            // Recompute size including children
            func calculateTotalSize() -> Int64 {
                if !isDir { return size }
                var total: Int64 = 0
                for child in children.values {
                    total += child.calculateTotalSize()
                }
                self.size = total
                return total
            }
            
            func toFileItem(fullPath: String, currentDepth: Int, maxDepth: Int) -> FileItem {
                let dummyURL = URL(fileURLWithPath: fullPath.isEmpty ? "/" : "/" + fullPath)
                var kind = isDir ? "Folder" : "ZIP Item"
                var icon: NSImage? = nil
                
                if !isDir {
                   if let type = UTType(filenameExtension: dummyURL.pathExtension) {
                       kind = type.localizedDescription ?? type.identifier
                       icon = NSWorkspace.shared.icon(for: type)
                   } else {
                        kind = dummyURL.pathExtension.isEmpty ? "Document" : "\(dummyURL.pathExtension.uppercased()) file"
                        icon = NSWorkspace.shared.icon(for: .data)
                   }
                } else {
                    icon = NSWorkspace.shared.icon(for: .folder)
                }
                
                // Recursion Limit check
                var childItems: [FileItem]? = nil
                if !children.isEmpty || isDir {
                    if currentDepth <= maxDepth {
                         childItems = children.values.map { $0.toFileItem(fullPath: (fullPath.isEmpty ? "" : fullPath + "/") + $0.name, currentDepth: currentDepth + 1, maxDepth: maxDepth) }
                         // We will sort childItems in the caller or here? 
                         // Logic below sorts children.
                    }
                }
                
                let sortedChildren = childItems?.sorted(using: [KeyPathComparator(\.url.lastPathComponent)])
                
                return FileItem(
                    id: dummyURL,
                    url: dummyURL,
                    children: sortedChildren,
                    icon: icon,
                    zipMetadata: zipMeta,
                    modificationDate: date,
                    fileSize: size,
                    kind: kind,
                    isDirectory: isDir
                )
            }
        }
        
        let root = Node(name: "")
        
        for entry in entries {
            let parts = entry.path.components(separatedBy: "/")
            var current = root
            
            for (index, part) in parts.enumerated() {
                if current.children[part] == nil {
                    current.children[part] = Node(name: part)
                }
                current = current.children[part]!
                
                if index == parts.count - 1 {
                    current.isDir = entry.isDir
                    current.date = entry.date
                    current.size = entry.size
                    current.zipMeta = entry.zipMeta
                }
            }
        }
        
        // Calculate deep sizes for all top-level nodes (and recursively)
        for child in root.children.values {
            _ = child.calculateTotalSize()
        }
        
        // Adjust depth for Smart Unwrapping
        // If there is exactly one root folder, the viewer will unwrap it (remove it),
        // effectively reducing the visible depth by 1. We compensate by increasing the limit.
        var effectiveMaxDepth = limitFolderDepth ? folderDepth : Int.max
        // Only boost if we are actually limiting
        if limitFolderDepth && root.children.count == 1, let singleChild = root.children.values.first, singleChild.isDir {
            effectiveMaxDepth += 1
        }
        
        // Convert to Items, starting at depth 1
        let items = root.children.values.map { $0.toFileItem(fullPath: $0.name, currentDepth: 1, maxDepth: effectiveMaxDepth) }
        return sortItems(items)
    }
    
    private func parseMSDOSDate(time: UInt16, date: UInt16) -> Date {
        // MS-DOS Date:
        // Bits 0-4: Day (1-31)
        // Bits 5-8: Month (1-12)
        // Bits 9-15: Year offset from 1980
        
        // MS-DOS Time:
        // Bits 0-4: Seconds / 2
        // Bits 5-10: Minutes (0-59)
        // Bits 11-15: Hours (0-23)
        
        let day = Int(date & 0x1F)
        let month = Int((date >> 5) & 0x0F)
        let year = Int((date >> 9) & 0x7F) + 1980
        
        let seconds = Int(time & 0x1F) * 2
        let minutes = Int((time >> 5) & 0x3F)
        let hours = Int((time >> 11) & 0x1F)
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hours
        components.minute = minutes
        components.second = seconds
        
        return Calendar.current.date(from: components) ?? Date()
    }
    
    // Legacy parser removed
    private func parseZipOutput(_ output: String) -> [FileItem] {
        return []
    }
    
    private func calculateDeepSize(at url: URL) -> Int64 {
        // ... existing implementation
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsPackageDescendants, .skipsHiddenFiles], errorHandler: nil) else { return 0 }
        
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
            
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .contentModificationDateKey, .fileSizeKey, .localizedTypeDescriptionKey]
            
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: options)
            
            return contents.compactMap { fileURL -> FileItem? in
                guard let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) else { return nil }
                
                let isDir = values.isDirectory ?? false
                let isPackage = values.isPackage ?? false
                let treatAsDir = isDir && !isPackage
                
                let date = values.contentModificationDate ?? Date()
                var size = values.fileSize.map { Int64($0) }
                // If it's a package, it might have a fileSize (sometimes 0 for bundles, need deep calc if we want accurate size, but strictly treating as file for speed is safer for now. actually packages usually have no file size returned by default resource key, it's 0. Deep calc for ALL apps is slow. Let's start with 0 or nil? Finder shows size for apps. calculateDeepSize handles packages? No, we skip descendants. )
                // For performance in /Applications, let's NOT deep calc individual apps automatically if they are top level, OR keep deep calc but skip package descendants (which means we won't get size? no, skip PREVENTS entering, but we want size... Finder calculates it.)
                // Actually, enumerator(.isPackageDescendants) means it treats package as a file.
                // Let's rely on standard logic: if treatAsDir is FALSE, we don't calculate deep size.
                // But Wait, Finder shows size for Apps.
                // If we treat it as a file, `values.fileSize` is usually nil or small for directories.
                // Let's stick to "Safety First": Treat as file, showing -- size if needed, to prevent the hang.
                
                let kind = values.localizedTypeDescription ?? (treatAsDir ? "Folder" : "File")
                
                if treatAsDir {
                    // Start with 0 for folders initially found
                    // Note: Calculating recursive size for EVERY folder in the view synchronously 
                    // is very expensive. For a smoother experience, we might want to do this async.
                    // However, for immediate valid data requested by user:
                    size = calculateDeepSize(at: fileURL)
                }
                
                var children: [FileItem]? = nil
                 // Check depth limit
                 let maxDepth = limitFolderDepth ? folderDepth : Int.max
                 if treatAsDir && currentDepth < maxDepth {
                    let childItems = fetchItems(at: fileURL, currentDepth: currentDepth + 1)
                    // Apply sort to children immediately
                    children = sortItems(childItems)
                }
                
                return FileItem(
                    id: fileURL,
                    url: fileURL,
                    children: children,
                    icon: nil, // Let ThumbnailView load system icon/preview
                    modificationDate: date,
                    fileSize: size,
                    kind: kind,
                    isDirectory: treatAsDir
                )
            }
        } catch {
            print("Error loading folder contents: \(error)")
            return []
        }
    }
}

import QuickLookThumbnailing
import Compression

struct ThumbnailView: View {
    let item: FileItem
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let explicitIcon = item.icon {
                Image(nsImage: explicitIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        // New Zip Logic
        if let meta = item.zipMetadata {
            // If it's an image type, try to extract and load
            // Only try for common image extensions to avoid waste
            let ext = item.url.pathExtension.lowercased()
            let imageExts: Set<String> = ["png", "jpg", "jpeg", "tif", "tiff", "gif", "bmp", "heic", "webp"]
            
            if imageExts.contains(ext) {
                 DispatchQueue.global(qos: .userInitiated).async {
                     if let img = extractZipImage(meta: meta) {
                         DispatchQueue.main.async {
                             self.image = img
                         }
                     }
                 }
            }
            return
        }
        
        // Existing logic for normal files
        if let icon = item.icon {
            // We have an explicit icon (maybe system default).
            // If it looks like an image, we still want QL to try generating a thumbnail 
            // because system icon is just a generic PNG file icon.
        }
        // ... (rest of existing QL/path logic)
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "webp", "svg", "pdf"]
        if imageExtensions.contains(item.url.pathExtension.lowercased()) {
            DispatchQueue.global(qos: .userInitiated).async {
                if let directImage = NSImage(contentsOf: item.url) {
                     DispatchQueue.main.async { self.image = directImage }
                     return
                }
                generateQLThumbnail()
            }
        } else {
            generateQLThumbnail()
        }
    }
    
    private func generateQLThumbnail() {
        let size = CGSize(width: 128, height: 128)
        let scale = 2.0
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: size, scale: scale, representationTypes: .thumbnail)
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { (thumbnail, error) in
            if let thumbnail = thumbnail {
                DispatchQueue.main.async {
                    self.image = thumbnail.nsImage
                }
            }
        }
    }
    
    private func extractZipImage(meta: ZipMetadata) -> NSImage? {
        guard let fileHandle = try? FileHandle(forReadingFrom: meta.sourceZipURL) else { return nil }
        defer { try? fileHandle.close() }
        
        do {
            // Go to Local Header
            try fileHandle.seek(toOffset: meta.localHeaderOffset)
            // Read Local Header (fixed 30 bytes + filename + extra)
            let headerData = fileHandle.readData(ofLength: 30)
            if headerData.count < 30 { return nil }
            
            let fileNameLen = headerData.subdata(in: 26..<28).withUnsafeBytes { $0.load(as: UInt16.self) }
            let extraFieldLen = headerData.subdata(in: 28..<30).withUnsafeBytes { $0.load(as: UInt16.self) }
            
            // Skip filename and extra field to get to data
            try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(fileNameLen) + UInt64(extraFieldLen))
            
            // Read Compressed Data
            let data = fileHandle.readData(ofLength: Int(meta.compressedSize))
            if data.count != Int(meta.compressedSize) { return nil }
            
            var uncompressedData: Data? = nil
            
            if meta.compressionMethod == 0 { // Store
                uncompressedData = data
            } else if meta.compressionMethod == 8 { // Deflate
                // Inflate using Compression Framework
                // Allocate buffer for uncompressed size
                let destSize = Int(meta.uncompressedSize)
                let maxSize = 50 * 1024 * 1024 // Cap at 50MB
                if destSize > maxSize { return nil }
                
                var destBuffer = [UInt8](repeating: 0, count: destSize)
                
                let bytesWritten = data.withUnsafeBytes { srcBuffer -> Int in
                    return destBuffer.withUnsafeMutableBufferPointer { dstBuffer -> Int in
                         return compression_decode_buffer(
                            dstBuffer.baseAddress!,
                            destSize,
                            srcBuffer.baseAddress!.bindMemory(to: UInt8.self, capacity: data.count),
                            data.count,
                            nil,
                            COMPRESSION_ZLIB
                        )
                    }
                }
                
                if bytesWritten == destSize {
                    uncompressedData = Data(destBuffer)
                }
            }
            
            if let uData = uncompressedData {
                return NSImage(data: uData)
            }
            
        } catch {
            print("Extraction failed: \(error)")
        }
        return nil
    }
}

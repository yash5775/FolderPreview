//
//  ContentView.swift
//  FolderPreview
//
//  Created by yash on 18/12/25.
//

import SwiftUI



struct ContentView: View {
    enum NavigationItem: String, CaseIterable, Identifiable {
        case home = "Home"
        case settings = "Folder preview"
        case about = "About"
        
        var id: String { self.rawValue }
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .settings: return "gearshape.fill"
            case .about: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .home: return .red
            case .settings: return .blue
            case .about: return .gray
            }
        }
    }
    
    @State private var selectedItem: NavigationItem? = .home
    
    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    Label {
                        Text(item.rawValue)
                    } icon: {
                        Image(systemName: item.icon)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(item.color)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .navigationTitle("Sidebar")
            .listStyle(SidebarListStyle())
        } detail: {
            switch selectedItem {
            case .home:
                HomeView()
            case .settings:
                SettingsView()
            case .about:
                AboutView()
            case nil:
                HomeView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}


#Preview {
    ContentView()
}

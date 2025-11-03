//
//  ContentView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//

// 2024 SkillTrade. Minden jog fenntartva. (All Rights Reserved)
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var userManager = UserManager.shared
    @StateObject private var serverAuth = ServerAuthManager.shared
    
    var body: some View {
        Group {
            if userManager.isAuthenticated || serverAuth.isAuthenticated {
                // Fő alkalmazás nézet TabView-val
                TabView(selection: $selectedTab) {
                    // Search tab
                    SearchView2(initialSearchText: "")
                        .tabItem {
                            Image("zoom2")
                            Text(NSLocalizedString("search", comment: ""))
                        }
                        .tag(0)
                    
                    // Profile tab
                    ProfilView()
                        .tabItem {
                            Image(systemName: "person")
                            Text(NSLocalizedString("Account", comment: ""))
                        }
                        .tag(2)
                }
            } else {
                // Bejelentkezési nézet
                LoginView()
//                SearchView2(initialSearchText: "")
            }
        }
        .environmentObject(UserManager.shared)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(UserManager.shared)
                .previewDisplayName("ContentView")
        }
    }
}
#endif

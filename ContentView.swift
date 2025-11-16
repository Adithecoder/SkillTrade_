// ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var userManager = UserManager.shared
    @StateObject private var serverAuth = ServerAuthManager.shared
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                // LoadingView2 használata betöltés közben
                LoadingView2()
            } else if userManager.isAuthenticated || serverAuth.isAuthenticated {
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
            }
        }
        .environmentObject(UserManager.shared)
        .onAppear {
            checkAuthenticationStatus()
        }
    }
    
    private func checkAuthenticationStatus() {
        print("🔐 CONTENTVIEW - Checking authentication status")
        
        // First check local authentication status
        if userManager.isAuthenticated {
            print("✅ CONTENTVIEW - UserManager shows authenticated")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isLoading = false
            }
            return
        }
        
        // Check server authentication with auto-login
        serverAuth.autoLogin { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ CONTENTVIEW - Auto-login successful")
                    self.userManager.isAuthenticated = true
                } else {
                    print("❌ CONTENTVIEW - Auto-login failed, showing login screen")
                    self.userManager.isAuthenticated = false
                    self.serverAuth.isAuthenticated = false
                }
                
                // Rövid késleltetés, hogy látható legyen a betöltőképernyő
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isLoading = false
                }
            }
        }
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

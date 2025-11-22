//
//  SkillTradeApp.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//

import SwiftUI

@main
struct SkillTradeApp: App {
    @StateObject private var serverAuth = ServerAuthManager.shared
    @State private var isCheckingAuth = true
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingAuth {
                    // LoadingView2 használata app indításkor
                    LoadingView2()
                } else {
                    ContentView()
                        .environmentObject(UserManager.shared)
                }
            }
            .onAppear {
                checkInitialAuthStatus()
            }
        }
    }
    
    private func checkInitialAuthStatus() {
        print("🚀 APP START - Checking initial auth status")
        
        // Rövid késleltetés, hogy látható legyen a betöltőképernyő
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            serverAuth.autoLogin { success in
                DispatchQueue.main.async {
                    print("🚀 APP START - Auto-login result: \(success)")
                    isCheckingAuth = false
                }
            }
        }
    }
}

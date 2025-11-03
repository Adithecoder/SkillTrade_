//
//  SkillTradeApp.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//

import SwiftUI

@main
struct SkillTradeApp: App {
    var body: some Scene {
        WindowGroup {
            StartWorkView(work: WorkData.mockWork)
                .environmentObject(UserManager.shared) // <- Itt add hozzá
        }
    }
}

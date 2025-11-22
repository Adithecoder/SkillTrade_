//
//  ProfileImageManager.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/22/25.
//


// ProfileImageManager.swift
import SwiftUI
import Combine

class ProfileImageManager: ObservableObject {
    static let shared = ProfileImageManager()
    
    @Published var profileImageData: Data?
    private let serverAuth = ServerAuthManager.shared
    
    private init() {
        loadProfileImage()
    }
    
    func loadProfileImage() {
        serverAuth.fetchProfileImage { [weak self] imageData in
            DispatchQueue.main.async {
                self?.profileImageData = imageData
            }
        }
    }
    
    func updateProfileImage(_ imageData: Data) {
        self.profileImageData = imageData
        
        // Feltöltés a szerverre
        serverAuth.uploadProfileImage(imageData) { success in
            if success {
                print("✅ Profilkép sikeresen frissítve")
            }
        }
    }
    
    func clearProfileImage() {
        profileImageData = nil
    }
}
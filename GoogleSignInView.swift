//
//  GoogleSignInView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/13/25.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import DesignSystem

struct SocialLoginView: View {
    @EnvironmentObject var authManager: ServerAuthManager
    @State private var isLoading = false
    @State private var currentAuthType: AuthType?
    
    enum AuthType {
        case google, apple
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Facebook bejelentkezés gomb
//            Button(action: {
//            }) {
//                VStack {
//                    if isLoading && currentAuthType == .apple {
//                        ProgressView()
//                            .scaleEffect(0.8)
//                    } else {
//                        Image("facebook 2")
//                            .resizable()
//                            .frame(width: 18, height: 18)
//                    }
//
//                    Text("Belépés Facebook-kal")
//                        .font(.custom("Lexend", size:12))
//                }
//                .foregroundColor(.white)
//                .frame(maxWidth: .infinity)
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 20)
//                        .fill(.blue)
//                        .stroke(Color.DesignSystem.descriptions, lineWidth: 3)
//                )
//                .cornerRadius(18)
//            }
//            .disabled(isLoading)
            Button(action: {
                signInWithApple()
            }) {
                VStack {
                    if isLoading && currentAuthType == .apple {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    Text("Folytatás Apple ID-vel")
                        .font(.custom("Lexend", size:12))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black)
                        .stroke(Color.DesignSystem.descriptions, lineWidth: 3)
                )
                .cornerRadius(18)
            }
            .disabled(isLoading)
            
            // Google bejelentkezés gomb
            Button(action: {
                signInWithGoogle()
            }) {
                VStack {
                    if isLoading && currentAuthType == .google {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image("googleicon")
                            .resizable()
                            .frame(width: 18, height: 18)
                    }
                    
                    Text("Bejelentkezés Google-lal")
                        .font(.custom("Lexend", size:12))
                        .foregroundColor(.white)

                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.25, green: 0.52, blue: 0.95), // Google Kék
                                Color(red: 0.91, green: 0.30, blue: 0.24), // Google Piros
                                Color(red: 0.98, green: 0.73, blue: 0.16), // Google Sárga
                                Color(red: 0.20, green: 0.81, blue: 0.36)  // Google Zöld
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.20, green: 0.81, blue: 0.36),  // Google Zöld
                                Color(red: 0.98, green: 0.73, blue: 0.16), // Google Sárga
                                Color(red: 0.91, green: 0.30, blue: 0.24), // Google Piros
                                Color(red: 0.25, green: 0.52, blue: 0.95), // Google Kék

                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 3)
                )
            }
            .disabled(isLoading)
        }
        
    }
    
    private func signInWithApple() {
        currentAuthType = .apple
        isLoading = true
        
        // Használd a GoogleSignInManager loginWithApple metódusát
        let nonce = randomNonceString()
        AppleSignInManager.shared.currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = AppleSignInManager.shared
        authorizationController.presentationContextProvider = AppleSignInManager.shared
        
        // Állítsd be a completion handler-t
        AppleSignInManager.shared.onCompletion = { success, token in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success, let token = token {
                    // Használd a GoogleSignInManager loginWithApple metódusát
                    GoogleSignInManager.sharedGoogle.loginWithApple(identityToken: token) { success in
                        DispatchQueue.main.async {
                            if success {
                                print("✅ Apple login successful")
                                // Frissítsd az authManager állapotát
                                self.authManager.isAuthenticated = true
                                self.authManager.currentUser = GoogleSignInManager.sharedGoogle.currentUser
                            } else {
                                print("❌ Apple login failed")
                            }
                        }
                    }
                } else {
                    print("❌ Apple sign in failed")
                    self.isLoading = false
                }
            }
        }
        
        authorizationController.performRequests()
    }
    
    private func signInWithGoogle() {
        currentAuthType = .google
        isLoading = true
        
        // Google bejelentkezés implementációja
        GoogleSignInManager.sharedGoogle.signInWithGoogle { success, token in
            DispatchQueue.main.async {
                self.isLoading = false
                if success, let token = token {
                    print("✅ Google sign in successful")
                    // Itt küldd el a token-t a szervernek
                } else {
                    print("❌ Google sign in failed")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

struct SocialLoginView_Previews: PreviewProvider {
    static var previews: some View {
        SocialLoginView()
            .environmentObject(ServerAuthManager.shared)
    }
}

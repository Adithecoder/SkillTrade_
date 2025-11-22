//
//  CreateReviewView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/8/25.
//

import SwiftUI
import DesignSystem
import Combine

struct CreateReviewView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = CreateReviewViewModel()
    @StateObject private var profileImageManager = ProfileImageManager.shared
    let service: Service
    let placeholder: String

    let reviewedUser: User
    let workId: UUID
    let workTitle: String
    let reviewType: ReviewType
    
    var body: some View {
        NavigationView {
                VStack(spacing: 20) {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18))
                                .foregroundColor(.DesignSystem.fokekszin)
                                .padding(8)
                                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("Értékelés írása")
                            .font(.custom("Lexend", size: 18))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.submitReview(
                                reviewedUser: reviewedUser,
                                workId: workId,
                                type: reviewType
                            )
                        }) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 16))
                                .foregroundStyle(viewModel.rating == 0 || viewModel.isLoading ? .gray : Color.DesignSystem.fokekszin )
                                .padding(8)
                                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .disabled(viewModel.rating == 0 || viewModel.isLoading)
                        


                    }
                    .padding(.horizontal)
                    .padding(.top, -50)
                    
                    
                    VStack(alignment: .leading) {
                        HStack(alignment: .center) {
                            ProfileImage(size: 30)
                            
                            VStack(alignment: .leading) {
                                Text("\(reviewedUser.name)")
                                    .font(.custom("Jellee", size: 18))
                                    .foregroundColor(.secondary)

                                Text(workTitle)
                                    .font(.custom("Lexend", size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: UserReviewsView()) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 12))
                                    
                                    Text(String(format: "%.1f", service.rating))
                                        .font(.custom("Jellee", size: 18))
                                        .foregroundColor(.black)
                                    
                                    Text("(\(service.reviewCount))")
                                        .font(.custom("Lexend", size: 12))
                                        .foregroundColor(.gray)
                                }
                            }                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 4)
                        )
                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                    .cornerRadius(20)
                    .padding()

                    // Csillag értékelés
                    VStack(spacing: 16) {
                        
                        StarRatingView(rating: $viewModel.rating)
                            .font(.title2)
                    }
                    .padding()
                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
                    .padding(.horizontal)
                    

                    
                    // Megjegyzés
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Megjegyzés (opcionális)")
                            .font(.custom("Jellee", size: 20))
                            .foregroundColor(.DesignSystem.fokekszin)
                        PlaceholderTextEditor(
                            text: $viewModel.comment,
                            placeholder: "Pl.: Nagyon igényesen végezte a rábízott munkát..."
                        )
                        .frame(height: 120)
                        .font(.custom("Jellee", size: 16))
                            .padding(8)
                            .scrollContentBackground(.hidden) // Elrejti az alapértelmezett háttért
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                    }
                    .padding(.horizontal)
                    
                    if reviewType == .employer {
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Kitűző hozzáadása (opcionális)")
                                .font(.custom("Jellee", size: 20))
                                .foregroundColor(.DesignSystem.fokekszin)
                            
                            VStack{
                            
                            Toggle(isOn: $viewModel.isReliable) {
                                HStack {
                                    Image(systemName: "checkmark.shield")
                                    Text("Megbízható partner")
                                        .font(.custom("Lexend", size: 16))

                                }
                            }
                            .tint(Color.DesignSystem.fokekszin)
                            
                            Toggle(isOn: $viewModel.isPaid) {
                                HStack {
                                    Image(systemName: "dollarsign.circle")
                                    Text("Kifizetés rendben volt")
                                        .font(.custom("Lexend", size: 16))

                                }
                            }
                            .tint(Color.DesignSystem.fokekszin)

                            
                        }
                            .padding()
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                        }
                        
                        .padding(.horizontal)
                    }

                    // Küldés gomb
                    Button(action: {
                        viewModel.submitReview(
                            reviewedUser: reviewedUser,
                            workId: workId,
                            type: reviewType
                        )
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Értékelés elküldése")
                                .font(.custom("Lexend", size:20))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.rating > 0 ?                     Color.DesignSystem.fokekszin : Color.DesignSystem.fokekszin.opacity(0.2))
                                .cornerRadius(20)
                        }
                    }
                    .disabled(viewModel.rating == 0 || viewModel.isLoading)
                    .padding()
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            
            .alert("Sikeres értékelés", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Köszönjük értékelésed!")
            }
            .alert("Hiba", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

import SwiftUI

struct PlaceholderTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // A tényleges TextEditor
            TextEditor(text: $text)
            
            if text.isEmpty {
                Text(placeholder)
                    .font(.custom("Jellee", size: 16))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false) // fontos: ne blokkolja a tap-eket
            }
        }
    }
}
// Csillag értékelés komponens
struct StarRatingView: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundColor(star <= rating ? .yellow : .DesignSystem.fokekszin)
                    .onTapGesture {
                        rating = star
                    }
                    .font(.title2)
            }
        }
    }
}

// ViewModel
class CreateReviewViewModel: ObservableObject {
    @Published var rating: Int = 0
    @Published var comment: String = ""
    @Published var isReliable: Bool = true
    @Published var isPaid: Bool = true
    @Published var isLoading: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""
    
    func submitReview(reviewedUser: User, workId: UUID, type: ReviewType) {
        guard let currentUser = UserManager.shared.currentUser else {
            errorMessage = "Nincs bejelentkezve felhasználó"
            showErrorAlert = true
            return
        }
        
        isLoading = true
        
        let reviewRequest = CreateReviewRequest(
            reviewerId: currentUser.id,
            reviewerName: currentUser.name,
            reviewedUserId: reviewedUser.id,
            workId: workId,
            rating: rating,
            comment: comment.isEmpty ? nil : comment,
            isReliable: type == .employer ? isReliable : nil,
            isPaid: type == .employer ? isPaid : nil,
            type: type == .employee ? "employee" : "employer"
        )
        
        Task {
            do {
                let success = try await ServerAuthManager.shared.createReview(reviewRequest)
                
                await MainActor.run {
                    isLoading = false
                    if success {
                        showSuccessAlert = true
                    } else {
                        errorMessage = "Ismeretlen hiba történt"
                        showErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

#if DEBUG
struct CreateReviewView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock service for preview
        let mockService = Service(
            advertiser: User.preview, // Itt kellene a valódi usert használni
            name: "iOS alkalmazás fejlesztése",
            description: "Professzionális iOS alkalmazás fejlesztése SwiftUI használatával",
            rating: 4.5,
            reviewCount: 12,
            price: 25000,
            location: "Budapest",
            skills: ["Programming", "Swift", "SwiftUI"],
            mediaURLs: [],
            availability: ServiceAvailability(serviceId: UUID()),
            typeofService: .technology,
            serviceOption: .premium
        )
        
        // Első preview - munkáltatói értékelés
        CreateReviewView(
            service: mockService, placeholder: "Írj véleményt",
            reviewedUser: User(
                name: "Kovács János",
                email: "kovacs.janos@example.com",
                username: "kovacsjanos",
                bio: "Tapasztalt iOS fejlesztő",
                rating: 4.5,
                reviews: [],
                location: Location(city: "Budapest", country: "Hungary"),
                skills: [Skill(name: "Programming")],
                pricing: [Pricing(price: 5000, unit: "óra")],
                isVerified: true,
                servicesOffered: "iOS alkalmazás fejlesztése",
                servicesAdvertised: "iOS alkalmazás fejlesztése",
                userRole: .client,
                status: .active,
                phoneNumber: "+36123456789",
                address: nil,
                profileImageUrl: nil,
                photos: [],
                xp: 1500,
                permanentQRCodeUrl: nil,
                typeofservice: "programming",
                price: 25000,
                age: 30,
                createdAt: Date(),
                updatedAt: Date()
            ),
            workId: UUID(),
            workTitle: "iOS alkalmazás fejlesztése",
            reviewType: .employer
        )
        
        // Második preview - munkavállalói értékelés (dark mode)
        CreateReviewView(
            service: mockService, placeholder: "",
            reviewedUser: User(
                name: "Nagy Eszter",
                email: "eszter.nagy@example.com",
                username: "nagyeszter",
                bio: "Kreatív designer",
                rating: 4.8,
                reviews: [],
                location: Location(city: "Budapest", country: "Hungary"),
                skills: [Skill(name: "Design")],
                pricing: [Pricing(price: 20000, unit: "projekt")],
                isVerified: true,
                servicesOffered: "UI/UX design",
                servicesAdvertised: "UI/UX design",
                userRole: .client,
                status: .active,
                phoneNumber: "+36123456780",
                address: nil,
                profileImageUrl: nil,
                photos: [],
                xp: 1200,
                permanentQRCodeUrl: nil,
                typeofservice: "design",
                price: 20000,
                age: 28,
                createdAt: Date(),
                updatedAt: Date()
            ),
            workId: UUID(),
            workTitle: "UI redesign projekt",
            reviewType: .employee
        )
        .preferredColorScheme(.dark)
    }
}
#endif

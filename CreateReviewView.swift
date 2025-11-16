//
//  CreateReviewView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/8/25.
//


import SwiftUI
import Combine


struct CreateReviewView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = CreateReviewViewModel()
    
    let reviewedUser: User
    let workId: UUID
    let workTitle: String
    let reviewType: ReviewType
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Fejléc
                    VStack(spacing: 12) {
                        Text("Értékelés írása")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(reviewedUser.name) értékelése")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(workTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Csillag értékelés
                    VStack(spacing: 16) {
                        Text("Általános értékelés")
                            .font(.headline)
                        
                        StarRatingView(rating: $viewModel.rating)
                            .font(.title2)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // További értékelési szempontok (munkáltatói értékeléshez)
                    if reviewType == .employer {
                        VStack(spacing: 16) {
                            Text("További értékelések")
                                .font(.headline)
                            
                            Toggle(isOn: $viewModel.isReliable) {
                                HStack {
                                    Image(systemName: "checkmark.shield")
                                    Text("Megbízható partner")
                                }
                            }
                            
                            Toggle(isOn: $viewModel.isPaid) {
                                HStack {
                                    Image(systemName: "dollarsign.circle")
                                    Text("Kifizetés rendben volt")
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Megjegyzés
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Megjegyzés (opcionális)")
                            .font(.headline)
                        
                        TextEditor(text: $viewModel.comment)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
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
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.rating > 0 ? Color.blue : Color.gray)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(viewModel.rating == 0 || viewModel.isLoading)
                    .padding()
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Mégse") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Küldés") {
                    viewModel.submitReview(
                        reviewedUser: reviewedUser,
                        workId: workId,
                        type: reviewType
                    )
                }
                .disabled(viewModel.rating == 0 || viewModel.isLoading)
            )
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
}

// Csillag értékelés komponens
struct StarRatingView: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundColor(star <= rating ? .yellow : .gray)
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


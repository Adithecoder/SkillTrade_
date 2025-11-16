import SwiftUI
import NaturalLanguage
import Combine
import DesignSystem
import Translation // 🔹 Új import – Apple Translation Framework

struct UserReviewsView: View {
    @StateObject private var viewModel = UserReviewsViewModel()
    @State private var selectedTab = 0
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                
                Text("Értékelések")
                    .font(.custom("Lexend", size: 18))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .fontWeight(.semibold)
                
                Spacer()
                
                    Image(systemName: "star")
                        .font(.system(size: 16))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .clipShape(Circle())
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Tabs
            Picker("Válassz", selection: $selectedTab) {
                Text("Munkavállalásaim").tag(0)
                Text("Hirdetett Munkáim").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Content
            TabView(selection: $selectedTab) {
                EmployeeReviewsView(reviews: viewModel.employeeReviews)
                    .tag(0)
                
                EmployerReviewsView(reviews: viewModel.employerReviews)
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.loadReviews() }
    }
}

// MARK: - Munkavállalói értékelések
struct EmployeeReviewsView: View {
    let reviews: [EmployeeReview]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if reviews.isEmpty {
                    EmptyStateView(
                        title: "Nincsenek munkavállalási értékelések",
                        message: "Még nem kaptál értékelést munkavállalóként.",
                        systemImage: "person.badge.clock"
                    )
                } else {
                    ForEach(reviews) { review in
                        EmployeeReviewCard(review: review)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Munkáltatói értékelések
struct EmployerReviewsView: View {
    let reviews: [EmployerReview]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if reviews.isEmpty {
                    EmptyStateView(
                        title: "Nincsenek hirdetett munka értékelések",
                        message: "Még nem kaptál értékelést munkáltatóként.",
                        systemImage: "briefcase"
                    )
                } else {
                    ForEach(reviews) { review in
                        EmployerReviewCard(review: review)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Munkavállalói értékelés kártya (fordítással)
struct EmployeeReviewCard: View {
    let review: EmployeeReview
    @State private var showingTranslation = false
    @State private var translatedComment = ""
    @State private var isTranslating = false
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.workTitle)
                        .font(.custom("Lexend", size:20))
                        .foregroundColor(.primary)
                    
                    Text("\(review.employerName)")
                        .font(.custom("Lexend", size:15))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(review.rating) ? "star.fill" : "star")
                            .foregroundColor(star <= Int(review.rating) ? .DesignSystem.descriptions : .gray)
                            .font(.caption)
                    }
                }
            }
            
            if !review.comment.isEmpty {
                Text(showingTranslation ? translatedComment : review.comment)
                    .font(.custom("Lexend", size:14))
                    .foregroundColor(.primary)
                    .padding(.vertical, 4)
            }
            
//            if !review.skills.isEmpty {
//                SkillsTagView(skills: review.skills)
//            }
            
            HStack {
                Button(action: translateComment) {
                    if isTranslating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .DesignSystem.fokekszin))
                    } else {
                        Text(showingTranslation ? "Eredeti" : "Fordítás")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color.DesignSystem.fokekszin.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                    }
                }
                Spacer()
                Text("\(review.date, formatter: dateFormatter)")
                    .font(.custom("Lexend", size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
        )
        .foregroundColor(.DesignSystem.fokekszin)
        .padding(4)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Fordítás
    private func translateComment() {
        guard !review.comment.isEmpty else { return }
        if showingTranslation {
            showingTranslation = false
            return
        }
        Task {
            isTranslating = true
            defer { isTranslating = false }
            
            do {
                let detectedLanguage = try await NLLanguageRecognizer.dominantLanguage(for: review.comment)
                let targetLang = locale.language.languageCode?.identifier ?? "en"
                
                let translator = try await Translator(from: detectedLanguage?.rawValue ?? "en", to: targetLang)
                let result = try await translator.translate(review.comment)
                translatedComment = result
                showingTranslation = true
            } catch {
                translatedComment = "❗ Fordítás nem elérhető."
                showingTranslation = true
            }
        }
    }
}

// MARK: - Munkáltatói értékelés kártya (fordítással)
struct EmployerReviewCard: View {
    let review: EmployerReview
    @State private var showingTranslation = false
    @State private var translatedComment = ""
    @State private var isTranslating = false
    @Environment(\.locale) private var locale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.workTitle)
                        .font(.custom("Lexend", size:20))
                        .foregroundColor(.primary)
                    
                    Text("\(review.employeeName)")
                        .font(.custom("Lexend", size:15))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                VStack{
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(review.rating) ? "star.fill" : "star")
                                .foregroundColor(star <= Int(review.rating) ? .DesignSystem.descriptions : .gray)
                                .font(.caption)
                        }
                    }

                }
            }

            
            if !review.comment.isEmpty {
                Text(showingTranslation ? translatedComment : review.comment)
                    .font(.custom("Lexend", size:14))
                    .foregroundColor(.primary)
                    .padding(.vertical, 4)
            }
            HStack {
                ReliabilityBadge(isReliable: review.isReliable)
                PaymentBadge(isPaid: review.isPaid)
            }
            .padding(.vertical, 4)
            HStack {
                Button(action: translateComment) {
                    if isTranslating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .DesignSystem.fokekszin))
                    } else {
                        Text(showingTranslation ? "Eredeti" : "Fordítás")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color.DesignSystem.fokekszin.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                    }
                }
                Spacer()
                Text("\(review.date, formatter: dateFormatter)")
                    .font(.custom("Lexend", size:12))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
        )
        .foregroundColor(.DesignSystem.fokekszin)
        .padding(4)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private func translateComment() {
        guard !review.comment.isEmpty else { return }
        if showingTranslation {
            showingTranslation = false
            return
        }
        Task {
            isTranslating = true
            defer { isTranslating = false }
            
            do {
                let detectedLanguage = try await NLLanguageRecognizer.dominantLanguage(for: review.comment)
                let targetLang = locale.language.languageCode?.identifier ?? "en"
                let translator = try await Translator(from: detectedLanguage?.rawValue ?? "en", to: targetLang)
                translatedComment = try await translator.translate(review.comment)
                showingTranslation = true
            } catch {
                translatedComment = "❗ Fordítás nem elérhető."
                showingTranslation = true
            }
        }
    }
}

// MARK: - Badge nézetek
struct ReliabilityBadge: View {
    let isReliable: Bool
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isReliable ? "checkmark.shield.fill" : "xmark.shield")
                .foregroundColor(isReliable ? .green : .red)
            Text(isReliable ? "Megbízható" : "Nem megbízható")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isReliable ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isReliable ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(6)
    }
}

struct PaymentBadge: View {
    let isPaid: Bool
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPaid ? "dollarsign.circle.fill" : "exclamationmark.circle")
                .foregroundColor(isPaid ? .green : .orange)
            Text(isPaid ? "Kifizetve" : "Függő")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isPaid ? .green : .orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isPaid ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Skills és üres állapot
struct SkillsTagView: View {
    let skills: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(skills, id: \.self) { skill in
                    Text(skill)
                        .font(.custom("Lexend", size:12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                        )
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(4)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text(title).font(.headline)
            Text(message).font(.body).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ViewModel + Modellek
class UserReviewsViewModel: ObservableObject {
    @Published var employeeReviews: [EmployeeReview] = []
    @Published var employerReviews: [EmployerReview] = []
    
    func loadReviews() {
        loadMockData()
    }
    
    private func loadMockData() {
        employeeReviews = [
            EmployeeReview(
                id: "1",
                workTitle: "Webfejlesztés",
                employerName: "Kovács János",
                rating: 5,
                comment: "Kiváló munkát végzett, pontos és megbízható volt.",
                skills: ["Swift", "iOS", "UI/UX", "Firebase"],
                date: Date().addingTimeInterval(-86400 * 7)
            )
        ]
        employerReviews = [
            EmployerReview(
                id: "1",
                workTitle: "iOS Fejlesztő",
                employeeName: "Tóth Gábor",
                rating: 5,
                comment: "Korrekt és megbízható partner.",
                isReliable: true,
                isPaid: true,
                date: Date().addingTimeInterval(-86400 * 3)
            )
        ]
    }
}

// MARK: - Adatmodellek
struct EmployeeReview: Identifiable {
    let id: String
    let workTitle: String
    let employerName: String
    let rating: Double
    let comment: String
    let skills: [String]
    let date: Date
}

struct EmployerReview: Identifiable {
    let id: String
    let workTitle: String
    let employeeName: String
    let rating: Double
    let comment: String
    let isReliable: Bool
    let isPaid: Bool
    let date: Date
}

// MARK: - Dátum formázó
private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    f.locale = Locale(identifier: "hu_HU")
    return f
}()

// MARK: - Preview
struct UserReviewsView_Previews: PreviewProvider {
    static var previews: some View {
        UserReviewsView()
    }
}

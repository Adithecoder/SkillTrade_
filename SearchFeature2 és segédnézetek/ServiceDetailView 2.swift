//
//  ServiceDetailView 2.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/5/25.
//


//
//  ServiceDetailView.swift
//  SkillTrade
//
//  Created by [Your Name] on [Date].
//

import SwiftUI
import DesignSystem

struct ServiceDetailView: View {
    let service: Service
    @Environment(\.presentationMode) var presentationMode
    @State private var showChat = false
    @State private var showingActionSheet = false
    @State private var isServiceSaved = false
    @State private var isServiceLiked = false
    @State private var hasApplied = false
    @State private var isApplying = false
    @State private var showApplicationResult = false
    @State private var applicationResultMessage = ""
    @State private var showLocationDetail = false
    @State private var selectedImageIndex = 0
    
    private let protectionModel = WorkerProtectionModel()
    private let serverAuthManager = ServerAuthManager.shared
    
    // A teljes ár számítása
    public var totalAmount: Double {
        let fee = protectionModel.calculateTotalFee(for: service.price)
        return service.price + fee
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Header rész - vissza gombbal és mentés gombbal
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text("Szolgáltatás részletei")
                        .font(.custom("Lexend", size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        toggleSave()
                    }) {
                        Image(systemName: isServiceSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 20))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                // Kép galéria (ha vannak képek)
                if !service.mediaURLs.isEmpty {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(service.mediaURLs.enumerated()), id: \.offset) { index, mediaURL in
                            AsyncImage(url: mediaURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 250)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 250)
                                    .overlay(
                                        ProgressView()
                                            .tint(.DesignSystem.fokekszin)
                                    )
                            }
                            .tag(index)
                        }
                    }
                    .frame(height: 250)
                    .tabViewStyle(PageTabViewStyle())
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
                
                // Fő információk kártya
                VStack(alignment: .leading, spacing: 16) {
                    // Szolgáltató információ
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: service.typeofService.systemName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(.DesignSystem.fokekszin)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(getEmployerName(from: service))
                                        .font(.custom("Lexend", size: 18))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    if service.advertiser.isVerified {
                                        VerifiedBadge(size: 18)
                                    }
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 14))
                                    
                                    Text(String(format: "%.1f", service.rating))
                                        .font(.custom("Lexend", size: 16))
                                        .foregroundColor(.primary)
                                    
                                    Text("(\(service.reviewCount) értékelés)")
                                        .font(.custom("Lexend", size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Ár megjelenítése
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(totalAmount)) Ft")
                                .font(.custom("Lexend", size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(.DesignSystem.bordosszin)
                            
                            Text("teljes ár")
                                .font(.custom("Lexend", size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                    
                    // Szolgáltatás neve és leírása
                    VStack(alignment: .leading, spacing: 12) {
                        Text(service.name)
                            .font(.custom("Lexend", size: 24))
                            .fontWeight(.bold)
                            .foregroundColor(.DesignSystem.fokekszin)
                        
                        if !service.description.isEmpty {
                            Text(service.description)
                                .font(.custom("Lexend", size: 16))
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                    }
                    
                    // Helyszín információ
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.DesignSystem.fokekszin)
                        
                        Text(service.location)
                            .font(.custom("Lexend", size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            showLocationDetail.toggle()
                        }) {
                            Text("Térkép")
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.DesignSystem.fokekszin)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 8)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal)
                
                // Szükséges készségek
                if !service.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Szükséges készségek")
                            .font(.custom("Lexend", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.DesignSystem.fokekszin)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(service.skills, id: \.self) { skill in
                                Text(skill)
                                    .font(.custom("Lexend", size: 14))
                                    .foregroundColor(.DesignSystem.fokekszin)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                }
                
                // Ár részletes felbontása
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ár felbontása")
                        .font(.custom("Lexend", size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Alapár")
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(Int(service.price)) Ft")
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Védelemi díj")
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(Int(protectionModel.calculateTotalFee(for: service.price))) Ft")
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.primary)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Végösszeg")
                                .font(.custom("Lexend", size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(.DesignSystem.fokekszin)
                            
                            Spacer()
                            
                            Text("\(Int(totalAmount)) Ft")
                                .font(.custom("Lexend", size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(.DesignSystem.bordosszin)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal)
                
                // Akció gombok
                VStack(spacing: 12) {
                    if hasApplied {
                        // Ha már jelentkezett
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                            
                            Text("Sikeresen jelentkeztél")
                                .font(.custom("Lexend", size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green, lineWidth: 2)
                        )
                    } else {
                        // Jelentkezés gomb
                        Button(action: {
                            applyForService()
                        }) {
                            HStack {
                                if isApplying {
                                    ProgressView()
                                        .scaleEffect(1.0)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    
                                    Text("Jelentkezés a munkára")
                                        .font(.custom("Lexend", size: 16))
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isApplying)
                    }
                    
                    // Üzenet küldés gomb
                    Button(action: {
                        showChat.toggle()
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                                .font(.system(size: 20))
                            
                            Text("Üzenet küldése")
                                .font(.custom("Lexend", size: 16))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.DesignSystem.fokekszin)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer(minLength: 30)
            }
            .padding(.vertical)
        }
        .background(Color.gray.opacity(0.05).ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showChat) {
            // ChatView(user: service.advertiser)
            Text("Üzenetek: \(service.advertiser.name)")
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showLocationDetail) {
            LocationDetailView(location: service.location)
                .presentationDetents([.medium, .large])
        }
        .alert("Jelentkezés eredménye", isPresented: $showApplicationResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(applicationResultMessage)
        }
        .onAppear {
            checkIfApplied()
            checkIfSaved()
        }
    }
    
    // MARK: - Segédfüggvények
    
    private func getEmployerName(from service: Service) -> String {
        if service.description.contains("által kínált munka") {
            return String(service.description.split(separator: " ").first ?? "")
        }
        return service.advertiser.name
    }
    
    private func applyForService() {
        guard serverAuthManager.isAuthenticated else {
            applicationResultMessage = "Jelentkezéshez előbb be kell jelentkezned!"
            showApplicationResult = true
            return
        }
        
        isApplying = true
        
        Task {
            do {
                let success = try await serverAuthManager.applyForWork(
                    workId: service.id,
                    applicantId: UserManager.shared.currentUser?.id ?? UUID(),
                    applicantName: UserManager.shared.currentUser?.name ?? "Ismeretlen",
                    serviceTitle: service.name,
                    employerId: service.advertiser.id
                )
                
                await MainActor.run {
                    isApplying = false
                    if success {
                        hasApplied = true
                        applicationResultMessage = "Sikeresen jelentkeztél a munkára!"
                        showApplicationResult = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showApplicationResult = false
                        }
                    } else {
                        applicationResultMessage = "A jelentkezés sikertelen. Próbáld újra később."
                        showApplicationResult = true
                    }
                }
            } catch {
                await MainActor.run {
                    isApplying = false
                    applicationResultMessage = "Hiba történt: \(error.localizedDescription)"
                    showApplicationResult = true
                }
            }
        }
    }
    
    private func checkIfApplied() {
        Task {
            let hasAppliedResult = await serverAuthManager.checkIfApplied(workId: service.id)
            await MainActor.run {
                self.hasApplied = hasAppliedResult
            }
        }
    }
    
    private func toggleSave() {
        // TODO: Implement save/unsave functionality
        isServiceSaved.toggle()
    }
    
    private func checkIfSaved() {
        // TODO: Check if service is saved by current user
        isServiceSaved = false // Placeholder
    }
}

#if DEBUG
struct ServiceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceDetailView(
            service: Service(
                id: UUID(),
                advertiser: User.preview,
                name: "Weboldal fejlesztés",
                description: "Modern, reszponzív weboldal készítése React-tal és Node.js-tel. A projekt tartalmazza a teljes frontend és backend fejlesztést, adatbázis tervezést és deployment-et. Ideális vállalkozások számára, akik online jelenlétet szeretnének kiépíteni.",
                rating: 4.8,
                reviewCount: 24,
                price: 50000,
                location: "Budapest, V. kerület, Deák Ferenc tér 5.",
                skills: ["React", "Node.js", "TypeScript", "CSS", "MongoDB", "Express"],
                mediaURLs: [
                    URL(string: "https://example.com/image1.jpg")!,
                    URL(string: "https://example.com/image2.jpg")!
                ],
                availability: ServiceAvailability(serviceId: UUID()),
                typeofService: .technology,
                serviceOption: .premium
            )
        )
        .previewDisplayName("Részletes nézet - Prémium szolgáltatás")
    }
}

struct ServiceDetailView_Free_Previews: PreviewProvider {
    static var previews: some View {
        ServiceDetailView(
            service: Service(
                id: UUID(),
                advertiser: User(
                    name: "Kovács János",
                    email: "kovacs.janos@example.com",
                    username: "kovacsjanos",
                    bio: "Tapasztalt kertész 10+ év tapasztalattal",
                    rating: 4.9,
                    location: Location(city: "Szeged", country: "Magyarország"),
                    skills: [Skill(name: "Kertészkedés")],
                    isVerified: true
                ),
                name: "Kertrendezés és növényápolás",
                description: "Profi kertrendezés és növényápolás otthoni és ipari környezetben. Szolgáltatásaim magukban foglalják a kerttervezést, növényültetést, gyomirtást, metszést és öntözést. Speciális igények esetén gyümölcsfák gondozását is vállalom.",
                rating: 4.9,
                reviewCount: 15,
                price: 25000,
                location: "Szeged, Belváros, Kossuth Lajos sugárút 25.",
                skills: ["Kertészkedés", "Növényápolás", "Favirágzás", "Öntözés", "Metszés"],
                mediaURLs: [],
                availability: ServiceAvailability(serviceId: UUID()),
                typeofService: .gardening,
                serviceOption: .free
            )
        )
        .previewDisplayName("Részletes nézet - Ingyenes szolgáltatás")
    }
}
#endif
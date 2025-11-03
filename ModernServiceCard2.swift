//
//  ModernServiceCard2.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/31/25.
//

import SwiftUI
import DesignSystem
// MARK: - ModernServiceCard
struct ModernServiceCard2: View {
    let service: Service
    @State private var showChat = false
    @State private var showingProtectionInfo = false
    @State private var showingActionSheet = false
    @State private var isServiceSaved = false
    @State private var isServiceLiked = false
    @State private var protectionFee: Double = 0
    @State private var profileImageUrl: URL?
    @Binding var servicePrice: Double
    @State private var hasApplied: Bool = false
    @State private var isApplying: Bool = false
    @State private var showApplicationResult: Bool = false
    @State private var applicationResultMessage: String = ""
    @State private var navigateToDetail: Bool = false
    
    @State private var showSaveMessage = false
    @State private var saveMessage = ""
    @State private var showLocationMap = false
    @State private var showLocationDetail = false
    private let protectionModel = WorkerProtectionModel()
    private let serverAuthManager = ServerAuthManager.shared
    
    // A teljes ár számítása
    public var totalAmount: Double {
        let fee = protectionModel.calculateTotalFee(for: servicePrice)
        return servicePrice + fee
    }
    
    private var formattedLocation: String {
        let maxLength = 25 // Maximális hossz
        if service.location.count > maxLength {
            return String(service.location.prefix(maxLength - 3)) + "..."
        }
        return service.location
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header rész - ez lesz a NavigationLink
            VStack {
                HStack {
                    HStack {
                        Image(systemName: service.typeofService.systemName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.DesignSystem.fokekszin)
                            .clipShape(Circle())
                        
                        if service.advertiser.profileImageUrl != nil {
                            AsyncImage(url: profileImageUrl) { image in
                                image.resizable()
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } placeholder: {
                                ProgressView()
                            }
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Image(systemName: "person")
                                        .foregroundStyle(.white)
)
                                .frame(width: 40, height: 40)
                                .offset(x: -20)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(getEmployerName(from: service))                            .font(.custom("Lexend", size: 16))
                        
                        if service.advertiser.isVerified {
                            VerifiedBadge(size: 20)
                        }
                    }
                    .offset(x: -20)

                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                        
                        Text(String(format: "%.1f", service.rating))
                            .font(.custom("Lexend", size: 18))
                            .foregroundColor(.black)
                        
                        Text("(\(service.reviewCount))")
                            .font(.custom("Lexend", size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .contentShape(Rectangle()) // Ez biztosítja, hogy a teljes terület kattintható legyen
            .onTapGesture {
                navigateToDetail = true
            }
            
            Divider()
                .frame(height: 1)
            
            HStack {
                Text(service.name)
                    .font(.custom("Lexend", size: 20))
                    .foregroundColor(Color.DesignSystem.fokekszin)

                
                Spacer()
                

            }
            
            HStack {
                Text(service.description ?? "No description")
                    .font(.custom("Lexend", size: 15))
                    .foregroundColor(.black)
                    .lineLimit(nil)
                    .frame(width: 230, height: nil, alignment: .leading)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.DesignSystem.bordosszin)
                        .frame(width: 60, height: 60)
                        .offset(x: 5)
                    Text("\(Int(totalAmount)) Ft")
                        .font(.custom("Lexend", size: 14))
                        .foregroundStyle(Color.DesignSystem.descriptions)
                        .offset(x: 5)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.DesignSystem.fokekszin)
                
                Text(formattedLocation)
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Button(action: {
                    showLocationDetail.toggle()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.DesignSystem.fokekszin)
                }
                .sheet(isPresented: $showLocationDetail) {
                    LocationDetailView(location: service.location)
                }
            }
            
            // JELENTKEZÉSI GOMB - JAVÍTOTT VERZIÓ
            HStack {
                if hasApplied {
                    // Ha már jelentkezett
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Jelentkezve")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green, lineWidth: 1)
                    )
                } else {
                    // Jelentkezés gomb - JAVÍTOTT
                    Button(action: {
                        applyForService()
                    }) {
                        HStack {
                            if isApplying {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Jelentkezem")
                                    .font(.custom("Lexend", size: 14))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle()) // FONTOS: PlainButtonStyle hozzáadása
                    .disabled(isApplying)
                }
                
                Spacer()
                
                // Üzenet gomb
                Button(action: { showChat.toggle() }) {
                    Image(systemName: "message")
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle()) // FONTOS: PlainButtonStyle hozzáadása
                .sheet(isPresented: $showChat) {
                    // ChatView(user: service.advertiser)
                    Text("Üzenetek: \(service.advertiser.name)")
                }
                
                // További opciók gomb
                Button(action: { showingActionSheet = true }) {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle()) // FONTOS: PlainButtonStyle hozzáadása
            }
            .padding(.top, 8)
            
            if showApplicationResult {
                Text(applicationResultMessage)
                    .font(.custom("Lexend", size: 12))
                    .foregroundColor(applicationResultMessage.contains("sikeres") ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .foregroundColor(.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .listRowBackground(Color.clear)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
        )
        .foregroundColor(.DesignSystem.fokekszin)
        .font(.custom("Lexend", size: 18))
        .accentColor(.DesignSystem.fokekszin)
        .listRowInsets(EdgeInsets())
        .padding(4)
        .onAppear {
            checkIfApplied()
        }
        .alert("Jelentkezés eredménye", isPresented: $showApplicationResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(applicationResultMessage)
        }
        .background(
            NavigationLink(
                destination: ServiceDetailView(service: service),
                isActive: $navigateToDetail,
                label: { EmptyView() }
            )
        )
    }
    
    // MARK: - Jelentkezési funkciók
    private func getEmployerName(from service: Service) -> String {
        // Ha a description tartalmazza a nevet, használjuk azt
        if service.description.contains("által kínált munka") {
            return String(service.description.split(separator: " ").first ?? "")
        }
        // Egyébként az advertiser neve
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
                        
                        // 3 másodperc után eltüntetjük az üzenetet
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
        // Ellenőrizzük, hogy a felhasználó már jelentkezett-e erre a szolgáltatásra
        Task {
            let hasAppliedResult = await serverAuthManager.checkIfApplied(workId: service.id)
            await MainActor.run {
                self.hasApplied = hasAppliedResult
            }
        }
    }
}
#if DEBUG
struct ModernServiceCard2_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Alap állapot - még nem jelentkeztek
            ModernServiceCard2(
                service: Service(
                    id: UUID(),
                    advertiser: User.preview,
                    name: "Weboldal fejlesztés",
                    description: "Modern, reszponzív weboldal készítése React-tal és Node.js-tel",
                    rating: 4.8,
                    reviewCount: 24,
                    price: 50000,
                    location: "Budapest, V. kerület",
                    skills: ["React", "Node.js", "TypeScript", "CSS"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .technology,
                    serviceOption: .premium
                ),
                servicePrice: .constant(50000)
            )
            .previewDisplayName("Alap állapot - Prémium")
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Ingyenes szolgáltatás
            ModernServiceCard2(
                service: Service(
                    id: UUID(),
                    advertiser: User(
                        name: "Kovács János",
                        email: "kovacs.janos@example.com",
                        username: "kovacsjanos",
                        bio: "Tapasztalt kertész",
                        rating: 4.9,
                        location: Location(city: "Szeged", country: "Magyarország"),
                        skills: [Skill(name: "Kertészkedés")],
                        isVerified: true
                    ),
                    name: "Kertrendezés",
                    description: "Profi kertrendezés és növényápolás",
                    rating: 4.9,
                    reviewCount: 15,
                    price: 25000,
                    location: "Szeged, Belváros",
                    skills: ["Kertészkedés", "Növényápolás", "Favirágzás"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .gardening,
                    serviceOption: .free
                ),
                servicePrice: .constant(25000)
            )
            .previewDisplayName("Ingyenes szolgáltatás")
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Már jelentkeztek
            ModernServiceCard2(
                service: Service(
                    id: UUID(),
                    advertiser: User.preview,
                    name: "Angol óra",
                    description: "Üzleti angol és konverzációs órák",
                    rating: 4.7,
                    reviewCount: 32,
                    price: 8000,
                    location: "Online",
                    skills: ["Angol", "Üzleti kommunikáció"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .education,
                    serviceOption: .premium
                ),
                servicePrice: .constant(8000)
            )
            .previewDisplayName("Már jelentkeztek")
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Jelentkezés közben
            ModernServiceCard2(
                service: Service(
                    id: UUID(),
                    advertiser: User.preview,
                    name: "Fotózás",
                    description: "Portré és termékfotózás",
                    rating: 4.6,
                    reviewCount: 18,
                    price: 35000,
                    location: "Budapest, XIII. kerület",
                    skills: ["Fotózás", "Photoshop", "Portré"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .arts,
                    serviceOption: .premium
                ),
                servicePrice: .constant(35000)
            )
            .previewDisplayName("Jelentkezés közben")
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Sötét mód
            ModernServiceCard2(
                service: Service(
                    id: UUID(),
                    advertiser: User.preview,
                    name: "Yoga óra",
                    description: "Hatha yoga kezdőknek és haladóknak",
                    rating: 4.9,
                    reviewCount: 42,
                    price: 6000,
                    location: "Budapest, II. kerület",
                    skills: ["Yoga", "Meditáció", "Testtudatosság"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .health,
                    serviceOption: .premium
                ),
                servicePrice: .constant(6000)
            )
            .previewDisplayName("Sötét mód")
            .padding()
            .background(Color.black)
            .preferredColorScheme(.dark)
        }
        .previewLayout(.sizeThatFits)
    }
}

// Helper preview a jelentkezési állapotok teszteléséhez
struct ModernServiceCard2_Interactive_Preview: View {
    @State private var servicePrice: Double = 45000
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ModernServiceCard2 - Interaktív Preview")
                .font(.title2)
                .bold()
                .padding()
            
            ModernServiceCard2(
                service: Service(
                    id: UUID(),
                    advertiser: User.preview,
                    name: "Interaktív teszt szolgáltatás",
                    description: "Ez egy teszt szolgáltatás a különböző állapotok megjelenítéséhez",
                    rating: 4.5,
                    reviewCount: 12,
                    price: 45000,
                    location: "Teszt helyszín, Budapest",
                    skills: ["Teszt", "Fejlesztés", "UI/UX"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .technology,
                    serviceOption: .premium
                ),
                servicePrice: $servicePrice
            )
            .padding()
            
            Text("Próbáld ki a jelentkezési gombot!")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct ModernServiceCard2_Interactive_Preview_Previews: PreviewProvider {
    static var previews: some View {
        ModernServiceCard2_Interactive_Preview()
    }
}

// Különböző kategóriák preview-ja
struct ModernServiceCard2_Categories_Preview: View {
    let services = [
        Service(
            id: UUID(),
            advertiser: User.preview,
            name: "React Native app",
            description: "Cross-platform mobilalkalmazás fejlesztése",
            rating: 4.8,
            reviewCount: 31,
            price: 120000,
            location: "Remote",
            skills: ["React Native", "JavaScript", "Firebase"],
            mediaURLs: [],
            availability: ServiceAvailability(serviceId: UUID()),
            typeofService: .technology,
            serviceOption: .premium
        ),
        Service(
            id: UUID(),
            advertiser: User.preview,
            name: "Életmód tanácsadás",
            description: "Egészséges életmód és táplálkozási tanácsok",
            rating: 4.6,
            reviewCount: 28,
            price: 15000,
            location: "Online",
            skills: ["Egészség", "Táplálkozás", "Edzés"],
            mediaURLs: [],
            availability: ServiceAvailability(serviceId: UUID()),
            typeofService: .health,
            serviceOption: .free
        ),
        Service(
            id: UUID(),
            advertiser: User.preview,
            name: "Vállalkozás indítás",
            description: "Üzleti terv és vállalkozás indítási támogatás",
            rating: 4.9,
            reviewCount: 19,
            price: 75000,
            location: "Budapest",
            skills: ["Üzleti terv", "Marketing", "Pénzügyek"],
            mediaURLs: [],
            availability: ServiceAvailability(serviceId: UUID()),
            typeofService: .business,
            serviceOption: .premium
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Különböző kategóriák")
                    .font(.title2)
                    .bold()
                    .padding()
                
                ForEach(services) { service in
                    ModernServiceCard2(
                        service: service,
                        servicePrice: .constant(service.price)
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ModernServiceCard2_Categories_Preview_Previews: PreviewProvider {
    static var previews: some View {
        ModernServiceCard2_Categories_Preview()
    }
}
#endif

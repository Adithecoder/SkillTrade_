// SearchFeature.swift - Teljes fájl

// MARK: - Imports
import SwiftUI
import Combine
import DesignSystem
import CoreLocation

struct TimeRangeSelectorView2: View {
    let weekDay: WeekDay
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) var dismiss
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var showingProtectionInfo = false
    
    
    var body: some View {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    DatePicker(NSLocalizedString("start", comment: ""),
                               
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.custom("OrelegaOne-Regular", size: 20))
                    .foregroundColor(Color.DesignSystem.descriptions)
                    .datePickerStyle(.automatic)
                    
                    Divider()
                        .frame(height: 2)
                        .background(Color.DesignSystem.descriptions)
                    DatePicker(NSLocalizedString("end", comment: ""),

                        selection: $endTime,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.custom("OrelegaOne-Regular", size: 20))
                    .foregroundColor(.DesignSystem.descriptions)
                    .datePickerStyle(.automatic)
                }
                .padding()
                .background(Color.DesignSystem.fokekszin)
                .cornerRadius(15)
                .shadow(color: Color.DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
                .padding()
                
                Button(action: {
                    let range = TimeRange(start: startTime, end: endTime)
                    calendarManager.addTimeRange(range, to: weekDay)
                    dismiss()
                }) {
                    Text(NSLocalizedString("add_time", comment: ""))
                        .font(.custom("OrelegaOne-Regular", size: 20))
                        .foregroundColor(.DesignSystem.descriptions)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.DesignSystem.fokekszin)
                        .cornerRadius(15)
                        .shadow(color: Color.DesignSystem.fokekszin, radius: 16,x:4, y: 4)
                }
                .disabled(endTime <= startTime)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(NSLocalizedString("new_time", comment:"" ))
                        .orelega()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: ""), action: { dismiss() })
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing))
                        .font(.custom("Lexend", size: 20))
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }


// MARK: - View Models
class SearchViewModel2: ObservableObject {
    
    @Published var selectedFizetesiMod: FizetesiMod = .bankkartya // Alapértelmezett érték

    @Published var searchText = ""
    @Published var services: [Service] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var filters = SearchFilters()
    @Published var filteredUsers: [User] = []
    @Published var allUsers: [User] = [] // Add this to store all users
    @Published var allServices: [Service] = [] // Add this to store all services
    @State private var selectedOption: ServiceOption = .free
    var workManager = WorkManager.shared
    var dbManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let serverAuthManager = ServerAuthManager.shared
    
    
    init(workManager: WorkManager = WorkManager.shared,
         dbManager: DatabaseManager = DatabaseManager.shared) {
        self.workManager = workManager
        self.dbManager = dbManager
        self.setupSearchSubscription()
        self.setupWorkManagerSubscription()
        self.loadAllUsers()
        self.loadWorksFromServer()
    }

    
    init() {
        setupSearchSubscription()
        setupWorkManagerSubscription()
        loadAllUsers()
    }
    
    init(initialSearchText: String = "") {
        self.searchText = initialSearchText
        setupSearchSubscription()
        setupWorkManagerSubscription()
        loadAllUsers()
    }
    
    private func loadWorksFromServer() {
            Task {
                guard serverAuthManager.isAuthenticated else {
                    print("🔐 Nincs hitelesítés - nem lehet munkákat betölteni")
                    await MainActor.run {
                        self.services = []
                    }
                    return
                }
                
                do {
                    let works = try await serverAuthManager.fetchWorks()
                    print("📥 Szerverről betöltött munkák: \(works.count)")
                    await MainActor.run {
                        self.updateServicesFromWorks(works)
                    }
                } catch {
                    print("❌ Hiba a works betöltése során: \(error)")
                    await MainActor.run {
                        self.services = []
                    }
                }
            }
        }
    
    func loadAllUsers() {
        isLoading = true
        dbManager.fetchAllUsers { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let users):
                    self?.allUsers = users
                    self?.filteredUsers = users
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
    
    private func setupSearchSubscription() {
        $searchText
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(searchText)
            }
            .store(in: &cancellables)
    }
    
    private func setupWorkManagerSubscription() {
        workManager.$publishedWorks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] works in
                self?.updateServicesFromWorks(works)
            }
            .store(in: &cancellables)
    }
    
    func performSearch(_ query: String) {
        let searchText = query.lowercased()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if searchText.isEmpty {
                // Ha üres a keresés, állítsuk vissza az eredeti listákat
                self.filteredUsers = self.allUsers
                self.services = self.allServices
                return
            }
            
            // Szűrés a tárolt teljes listákon
            self.filteredUsers = self.allUsers.filter { user in
                user.name.lowercased().contains(searchText) ||
                user.username.lowercased().contains(searchText) ||
                user.skills.contains { $0.name.lowercased().contains(searchText) }
            }
            
            self.services = self.allServices.filter { service in
                service.name.lowercased().contains(searchText) ||
                service.skills.contains { $0.lowercased().contains(searchText) }
            }
        }
    }
    
    func updateServicesFromWorks(_ works: [WorkData]) {
        let newServices = works.map { work -> Service in
            Service(
                advertiser: User.preview, // Itt kellene a valódi usert használni
                name: work.title,
                description: work.description ?? "\(work.employerName) által kínált munka",
                rating: 0.0,
                reviewCount: 0,
                price: work.wage,
                location: work.location,
                skills: work.skills,
                mediaURLs: [],
                availability: ServiceAvailability(serviceId: work.id),
                typeofService: .other,
                serviceOption: .free
            )
        }

        DispatchQueue.main.async {
            self.allServices = newServices
            self.services = newServices
        }
    }
    
    
    func addService(_ service: Service) {
           print("🔐 Szerver hitelesítés állapota: \(serverAuthManager.isAuthenticated)")
           
           // Ellenőrizzük a kötelező mezőket
           guard !service.name.isEmpty, !service.description.isEmpty else {
               print("❌ Hiányzó szolgáltatás adatok")
               return
           }
           
           // Fizetési mód konverzió
           let paymentTypeString: String
           switch selectedFizetesiMod {
           case .bankkartya:
               paymentTypeString = "Bankkártya"
           case .keszpenz:
               paymentTypeString = "Készpénz"
           case .atutalas:
               paymentTypeString = "Átutalás"
           }
           
           // WorkData létrehozása minden szükséges adattal
           let work = WorkData(
               id: service.availability.serviceId,
               title: service.name,
               employerName: service.advertiser.name,
               employerID: service.advertiser.id,
               employeeID: nil,
               wage: service.price,
               paymentType: paymentTypeString,
               statusText: "Publikálva",
               startTime: nil,
               endTime: nil,
               duration: nil,
               progress: 0.0,
               location: service.location,
               skills: service.skills,
               category: service.typeofService.rawValue,
               description: service.description,
               createdAt: Date()
           )
           
           print("🛠️ Munka létrehozva szerverre küldésre:")
           print("   - ID: \(work.id)")
           print("   - Cím: \(work.title)")
           print("   - Munkáltató: \(work.employerName)")
           print("   - Munkáltató ID: \(work.employerID)")
           print("   - Bér: \(work.wage)")
           print("   - Hely: \(work.location)")
           
           Task {
               do {
                   print("🚀 Munka küldése a szerverre...")
                   try await workManager.publishWork(work)
                   print("✅ Munka sikeresen felkerült a szerverre!")
                   
                   // Frissítjük a listát
                   await MainActor.run {
                       self.loadWorksFromServer()
                   }
                   
               } catch {
                   print("❌ Hiba a munka publikálásakor: \(error)")
                   // Csak szerveres megoldás, nincs lokális fallback
               }
           }
       }
    
    func deleteService(at offsets: IndexSet) {
        services.remove(atOffsets: offsets)
    }
}
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
    @State private var navigateToReviews: Bool = false
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
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .contentShape(Rectangle()) // Ez biztosítja, hogy a teljes terület kattintható legyen
            .onTapGesture {
                navigateToDetail = true
            }
            
            Divider()
                .overlay(Rectangle()
                    .frame(height: 2))
                .foregroundColor(.DesignSystem.fokekszin)
            
            
                HStack {
                    Text(service.name)
                        .font(.custom("Lexend", size: 20))
                        .foregroundColor(Color.DesignSystem.fokekszin)
                        .onTapGesture {
                                    navigateToDetail = true
                                }
                    
                    Spacer()
                    
                    
                
            }
                .padding(.bottom, -20)

            
            HStack {
//               Text(service.description ?? "No description")
//                   .font(.custom("Lexend", size: 15))
//                   .foregroundColor(.black)
//                   .lineLimit(nil)
//                   .frame(width: 230, height: nil, alignment: .leading)
                
                if !service.description.isEmpty {
                    Text(service.description)
                        .font(.custom("Lexend", size: 14))
                        .foregroundStyle(Color.DesignSystem.bordosszin)
                        .lineLimit(2) // Maximum 2 sor
                }
                Spacer()
                
                ZStack {
                    
                    Circle()
                        .fill(Color.DesignSystem.fokekszin.opacity(0.1))
                        .frame(width: 70, height: 70)
                        .zIndex(0)
                    
                    VStack{
                        Text("\(Int(totalAmount))")
                            .font(.custom("Lexend", size: 14))
                            .foregroundStyle(Color.DesignSystem.fenyozold)
                            .zIndex(2)
                        
                        Text("Ft")
                            .font(.custom("Jellee", size: 14))
                            .foregroundStyle(Color.DesignSystem.fenyozold)
                    }
                    .offset(y:2)
                }
                
                .overlay(
                    Circle()
                        .stroke(Color.DesignSystem.bordosszin, lineWidth: 2)
                        .zIndex(1)
                )
                .offset(x: 5)

            }
            .padding(.bottom, -20)

            
            HStack(spacing: 4) {
                
                Button(action: {
                    showLocationDetail.toggle()
                }) {
                    
                Image(systemName: "mappin.circle.fill")
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.DesignSystem.fokekszin)
                
                Text(formattedLocation)
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                

                    Image(systemName: "chevron.right")
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.DesignSystem.fokekszin)
                }
                .sheet(isPresented: $showLocationDetail) {
                    LocationDetailView(location: service.location)
                }
            }
            .padding(.bottom, -10)
            
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
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(.black)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(Color.DesignSystem.fokekszin.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 4)
                        )
                        .cornerRadius(13)
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
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                        )
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
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                        )
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
        // A ModernServiceCard2 végén található ez a rész:
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
            applicationResultMessage = "Munkára jelentkezéshez előbb be kell jelentkezned!"
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
struct SearchView2_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
                SearchView2(initialSearchText: "")
                    .environmentObject(UserManager.shared)
            
            .previewDisplayName("Light Mode")
            
            // Dark mode preview
            NavigationView {
                SearchView2(initialSearchText: "")
                    .environmentObject(UserManager.shared)
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
            
            // AI Bot version preview
                SearchView2(initialSearchText: "Sample search", fromAIBot: true)
                    .environmentObject(UserManager.shared)
            
            .previewDisplayName("From AI Bot")
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



#endif

// MARK: - Views

struct SearchView2: View {
    
    let workManager: WorkManager // Adj hozzá egy workManager property-t
    
    @StateObject private var viewModel = SearchViewModel2()
    @State private var selectedUser: User?
    @State private var serviceOption: ServiceOption = .free
    @State private var showFilters = false
    @State private var showServicePopup = false
    @State private var serviceName = ""
    @State private var serviceDescription = ""
    @State private var serviceRating: Double = 0
    @State private var serviceReviewCount: Int = 0
    @State private var servicePrice: Double = 0
    @State private var serviceLocation = ""
    @State private var serviceSkills: [String] = []
    @State private var serviceMediaURLs: [URL] = []
    @State private var serviceType: TypeofService = .other
    @State private var showAlert = false
    @State private var showSecondaryButtons = false
    @State private var isPremium: Bool = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) var dismiss
    let fromAIBot: Bool
    @State private var isRotating = false
    @State private var isPulsing = false
    @State private var isButtonAnimating = false
    @State private var selectedServiceForDetail: Service?
    @State private var selectedService: Service?
    @ObservedObject private var userManager = UserManager.shared
    
    // Add the initialSearchText property
    let initialSearchText: String
    
    // Initialize the searchText state variable with initialSearchText
    // Update init to include fromAIBot parameter
    
    
    init(initialSearchText: String, fromAIBot: Bool = false, workManager: WorkManager = WorkManager.shared) {
        self.initialSearchText = initialSearchText
        self.fromAIBot = fromAIBot
        self.workManager = workManager
        // Only pass initialSearchText if fromAIBot is true
        _viewModel = StateObject(wrappedValue: SearchViewModel2(initialSearchText: fromAIBot ? initialSearchText : ""))
    }
    
    
    var body: some View {
            ZStack {
//                animatedBackgroundElements
                
//                Image("hatter2")
//                                .resizable()
//                                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {

                    
                    // Modern Header Section with increased spacing
                    
                    
                    
                    VStack(spacing: 16) {
                        
                        
                        
                        Text(NSLocalizedString("Keress munkalehetőségek közül", comment:"" ))
                            .font(.custom("Jellee", size: 20))
                            .foregroundColor(Color.DesignSystem.fokekszin) // Dinamikus színváltás
                            .multilineTextAlignment(.center)
                        
                        
                        if fromAIBot {
                            HStack {
                                Button(action: { dismiss() }) {
                                    HStack(spacing: 5) {
                                        Spacer() // Ez tolja a tartalmat jobbra
                                        Text(NSLocalizedString("back_ai", comment: ""))
                                            .font(.custom("Lexend", size: 16))
                                            .foregroundColor(.black)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.custom("Lexend", size: 16))
                                            .foregroundColor(.black)
                                        
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                }
                                Spacer()
                            }
                        }
                        
                        // Modern Search Bar with adjusted padding
                        HStack(spacing: 12) {
                            HStack(spacing: 5) {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 25)
                                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .top, endPoint: .bottom))
                                    .background(.white)
                                    .cornerRadius(40)
                                    .symbolEffect(.bounce.down.wholeSymbol, options: .nonRepeating)
                                    .padding(.horizontal, 5)
                                
                                TextField((NSLocalizedString("search_placeholder", comment:"" )), text: $viewModel.searchText)
                                    .font(.custom("Jellee", size:16))
                                
                                // Kisebb, kompakt szűrő ikon
                                Button(action: { showFilters.toggle() }) {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 25)
                                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .top, endPoint: .bottom))
                                        .background(.white)
                                        .cornerRadius(40)
                                        .symbolEffect(.bounce.down.wholeSymbol, options: .nonRepeating)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 6)
                            )
             
                            .background(Color(.indigo.opacity(0.1)))
                            .cornerRadius(20)
                        }
                        .padding(.horizontal, 10)
                        
                    }
                    .padding(.vertical, 60)
                    
                    // Ingyenes vagy Prémium szolgáltatások választója
                    //                ingyenesvagypremiumView2(serviceOption: //$serviceOption, viewModel: //SettingsViewModel2(user: User.preview)) //// Átadjuk a binding változót
                    //                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Spacer()
                    } else {
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                // Szűrés a serviceOption alapján
                                let filteredServices = serviceOption == .free ? viewModel.services : viewModel.services.filter { $0.typeofService == .other }
                                ForEach(filteredServices) { service in
                                    ModernServiceCard2(service: service, servicePrice: .constant(service.price))
                                }
                                
                                
                                if !viewModel.services.isEmpty || !viewModel.filteredUsers.isEmpty {
                                    ForEach(viewModel.services) { service in
                                        ModernServiceCard2(service: service, servicePrice: .constant(service.price))
                                            .onTapGesture {
                                                // Navigáció a ServiceDetailView-hez
                                                selectedService = service
                                            }
                                    }
                                }
                                
                                if viewModel.filteredUsers.isEmpty && viewModel.services.isEmpty {
                                    Text(NSLocalizedString("not-found", comment: ""))
                                        .font(.custom("Lexend", size:20))
                                        .foregroundColor(.red)
                                        .padding(.top, -10)
                                }
                            }
                            .padding(8)
                        }
                        .background(
                            NavigationLink(
                                destination: Group {
                                    if let service = selectedServiceForDetail {
                                        ServiceDetailView(service: service)
                                    }
                                },
                                isActive: Binding(
                                    get: { selectedServiceForDetail != nil },
                                    set: { if !$0 { selectedServiceForDetail = nil } }
                                ),
                                label: { EmptyView() }
                            )
                        )
                    }
                    
                    // Gombok elhelyezése egymás mellett, de függetlenül mozognak
                    HStack(spacing: 16) {
                        Button(action: { showServicePopup.toggle() }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 25)
                                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .top, endPoint: .bottom))
                                    .background(.white)
                                    .cornerRadius(40)
                                    .symbolEffect(.bounce.down.wholeSymbol, options: .nonRepeating)
                                    .padding(.horizontal, 5)
                                Text(NSLocalizedString("create_service", comment:"" ))
                                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing))
                                    .symbolEffect(.bounce.down.wholeSymbol, options: .nonRepeating)
                                    .font(.custom("Jellee", size: 22))
                            }
                            
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 4)
                            
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.7))
                        )
                        .cornerRadius(15)
                        .shadow(color: Color.DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
                        .padding(.vertical, 50)

                        
                        // Modern Expandable Button
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                                showSecondaryButtons.toggle()
                            }
                        }) {
                            ZStack {
                                // Pulsating background effect
                                Circle()
                                    .fill(Color.DesignSystem.fokekszin)
                                    .scaleEffect(showSecondaryButtons ? 1.2 : 1)
                                    .animation(.easeInOut(duration: 0.3), value: showSecondaryButtons)
                                
                                // Main button icon
                                Image( showSecondaryButtons ? "material-symbol2" : "material-symbol")
                                    .font(.system(size: 24, weight: .heavy))
                                    .shadow(color: .DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
                            }
                            .padding(.vertical, 8)
                            
                            .frame(width: 46, height: 46)
                            .cornerRadius(25)
                            .background(Color.DesignSystem.fokekszin)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(color: .DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
                        }
                        
                        // Expandable secondary buttons
                        if showSecondaryButtons {
                            HStack(spacing: 15) {
                                // SkillVault Button
                                //                            NavigationLink(destination: //SkillVaultView().navigationBarBackButtonHidden(false)) {
                                //                                VStack(spacing: 8) {
                                //                                    ZStack {
                                //
                                //
                                //                                        Image( "vault")
                                //                                            .font(.system(size: 22, weight: .bold))
                                //                                            .foregroundColor(.white)
                                //                                            .shadow(color: .black.opacity(0.2), radius: 3, x: //0, y: 1)
                                //                                    }
                                //                                    .frame(width: 50, height: 50)
                                //                                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                                //
                                //                                    Text("SkillVault")
                                //                                        .font(.custom("OrelegaOne-Regular", size: 14))        //                            .fontWeight(.semibold)
                                //                                        .foregroundColor(.primary)
                                //                                }
                                //                                .padding(8)
                                //                                .background(Color.white.opacity(0.1))
                                //                                .cornerRadius(15)
                                //                            }
                                
                                // Profile View Button
                                //                            NavigationLink(destination: ProfileView2(user: //userManager.currentUser ?? User.preview)) {
                                //                                VStack(spacing: 8) {
                                //                                    ZStack {
                                //
                                //
                                //                                        Image("profile")
                                //                                            .font(.system(size: 22, weight: .bold))
                                //                                            .foregroundColor(.white)
                                //                                            .shadow(color: .black.opacity(0.2), radius: 3, x: //0, y: 1)
                                //                                    }
                                //                                    .frame(width: 50, height: 50)
                                //                                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                                //
                                //                                    Text("Profil")
                                //                                        .font(.custom("OrelegaOne-Regular", size: 14))        //                            .fontWeight(.semibold)
                                //                                        .foregroundColor(.primary)
                                //                                }
                                //                                .padding(8)
                                //                                .background(Color.white.opacity(0.1))
                                //                                .cornerRadius(15)
                                //                            }
                            }
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).animation(.spring()),
                                removal: .scale.combined(with: .opacity).animation(.spring())
                            ))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: showSecondaryButtons)
                }

                .navigationBarHidden(true)
                .ignoresSafeArea()
                .sheet(isPresented: $showFilters) {
                    FilterView2(filters: $viewModel.filters)
                }
                
                .sheet(isPresented: $showServicePopup) {
                    ServiceCreationPopup2(
                        //                    viewModel: SettingsViewModel3(user: .preview),
                        serviceName: $serviceName,
                        serviceDescription: $serviceDescription,
                        serviceRating: $serviceRating,
                        serviceReviewCount: $serviceReviewCount,
                        servicePrice: $servicePrice,
                        serviceLocation: $serviceLocation,
                        serviceSkills: $serviceSkills,
                        serviceMediaURLs: $serviceMediaURLs,
                        serviceType: $serviceType,
                        isPremium: $isPremium,
                        onCreate: { service in viewModel.addService(service) }
                    )
                    .environmentObject(userManager)
                }
                .onAppear {
                    viewModel.performSearch(viewModel.searchText)
                }
            
            }}
        public var animatedBackgroundElements: some View {
            ZStack {
                // Large rotating circles (existing)
                Circle()
                    .fill(Color.DesignSystem.fokekszin.opacity(0.2))
                    .frame(width: 300)
                    .offset(x: -UIScreen.main.bounds.width/3, y: -UIScreen.main.bounds.height/3)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(Animation.linear(duration: 20).repeatForever(autoreverses: false), value: isRotating)
                
                Circle()
                    .fill(Color.DesignSystem.bordosszin.opacity(0.2))
                    .frame(width: 400)
                    .offset(x: UIScreen.main.bounds.width/3, y: UIScreen.main.bounds.height/4)
                    .rotationEffect(.degrees(isRotating ? -360 : 0))
                    .animation(Animation.linear(duration: 25).repeatForever(autoreverses: false), value: isRotating)
                
                // Medium pulsing circles (existing)
                Circle()
                    .fill(Color.DesignSystem.sargaska.opacity(0.2))
                    .frame(width: 200)
                    .offset(x: UIScreen.main.bounds.width/4, y: -UIScreen.main.bounds.height/3)
                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                    .animation(Animation.easeInOut(duration: 3).repeatForever(), value: isPulsing)
                
                // NEW: Additional background elements
                // Small fast rotating circles
                Circle()
                    .fill(Color.DesignSystem.fokekszin.opacity(0.15))
                    .frame(width: 150)
                    .offset(x: UIScreen.main.bounds.width/2.5, y: UIScreen.main.bounds.height/2.5)
                    .rotationEffect(.degrees(isRotating ? 720 : 0))
                    .animation(Animation.linear(duration: 15).repeatForever(autoreverses: false), value: isRotating)
                
                Circle()
                    .fill(Color.DesignSystem.sargaska.opacity(0.15))
                    .frame(width: 180)
                    .offset(x: -UIScreen.main.bounds.width/2.8, y: UIScreen.main.bounds.height/3)
                    .rotationEffect(.degrees(isRotating ? -540 : 0))
                    .animation(Animation.linear(duration: 18).repeatForever(autoreverses: false), value: isRotating)
                
                // Tiny floating dots
                Circle()
                    .fill(Color.DesignSystem.descriptions.opacity(0.1))
                    .frame(width: 80)
                    .offset(x: UIScreen.main.bounds.width/5, y: -UIScreen.main.bounds.height/5)
                    .scaleEffect(isPulsing ? 1.5 : 0.7)
                    .animation(Animation.easeInOut(duration: 4).repeatForever(), value: isPulsing)
                
                Circle()
                    .fill(Color.DesignSystem.fokekszin)
                    .frame(width: 60)
                    .offset(x: -UIScreen.main.bounds.width/4, y: UIScreen.main.bounds.height/5)
                    .scaleEffect(isPulsing ? 1.3 : 0.6)
                    .animation(Animation.easeInOut(duration: 5).repeatForever().delay(0.5), value: isPulsing)
                
                // Subtle background grid pattern
                ForEach(0..<5) { i in
                    Path { path in
                        let yPos = CGFloat(i) * UIScreen.main.bounds.height/4
                        path.move(to: CGPoint(x: 0, y: yPos))
                        path.addLine(to: CGPoint(x: UIScreen.main.bounds.width, y: yPos))
                    }
                    .stroke(Color.DesignSystem.descriptions.opacity(0.05), lineWidth: 1)
                    
                    Path { path in
                        let xPos = CGFloat(i) * UIScreen.main.bounds.width/4
                        path.move(to: CGPoint(x: xPos, y: 0))
                        path.addLine(to: CGPoint(x: xPos, y: UIScreen.main.bounds.height))
                    }
                    .stroke(Color.DesignSystem.descriptions.opacity(0.05), lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                isRotating = true
                isPulsing = true
            }
        }
        
    
    
        func addService(_ service: Service) {
            // Először konvertáljuk a FizetesiMod enumot Stringgé
            let paymentTypeString: String
            switch viewModel.selectedFizetesiMod {  // Itt a viewModel.selectedFizetesiMod-ra van szükség
            case .bankkartya:
                paymentTypeString = "Bankkártya"
            case .keszpenz:
                paymentTypeString = "Készpénz"
                
            case .atutalas:
                paymentTypeString = "Átutalás"
            }
            
            let work = WorkData(
                id: service.availability.serviceId,
                title: service.name,
                employerName: service.advertiser.name,
                employerID: service.advertiser.id,
                employeeID: nil,
                wage: service.price,
                paymentType: paymentTypeString,  // Itt a konvertált String érték
                statusText: "Publikálva",
                startTime: nil,
                endTime: nil,
                duration: nil,
                progress: 0.0
            )
            
            Task {
                do {
                    try await workManager.publishWork(work)
                } catch {
                    print("Hiba a munka publikálásakor: \(error)")
                }
            }
        }
        
        private func resetServiceForm() {
            serviceName = ""
            serviceDescription = ""
            serviceRating = 0
            serviceReviewCount = 0
            servicePrice = 0
            serviceLocation = ""
            serviceSkills = []
            serviceMediaURLs = []
            serviceType = .other
            showServicePopup = false
        }
    }
    
    // struct ingyenesvagypremiumView2: View {
    //     @State private var selectedOption: ServiceOption = .free
    //     @Binding var serviceOption: ServiceOption // Use the ServiceOption from Types.swift
    //     @ObservedObject var viewModel: SettingsViewModel2
    //
    //     var body: some View {
    //
    //
    //         VStack(spacing: 20) {
    //             HStack(spacing: 20) {
    //                 ForEach(ServiceOption.allCases, id: \.self) { option in
    //                     Button(action: {
    //                         selectedOption = option
    //                         serviceOption = option // Update the binding
    //                     }) {
    //                         Text(option.localized)
    //                             .font(.custom("OrelegaOne-Regular", size: 20))
    //                             .foregroundColor(selectedOption == option ? // .DesignSystem.descriptions : viewModel.isDarkMode ? // Color.white : Color.black)
    //                             .padding()
    //                             .frame(maxWidth: .infinity)
    //                             .background(selectedOption == option ? // Color.DesignSystem.fokekszin : Color(.clear))
    //                             .cornerRadius(20)
    //                             .overlay(
    //                               RoundedRectangle(cornerRadius: 20)
    //                                 .stroke(selectedOption == option ? // Color.DesignSystem.fokekszin : // Color.DesignSystem.descriptions, lineWidth: 1)
    //                                                 )
    //                         .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, // y: 4)                    }
    //                 }
    //
    //             }
    //
    //             VStack {
    //                 Text(selectedOption.localized + " " + NSLocalizedString("selected", value: // "kiválasztva", comment: ""))
    //                     .font(.custom("OrelegaOne-Regular", size: 16))
    //                     .foregroundColor(viewModel.isDarkMode ? Color.white : Color.black)
    //             }
    //             .padding(-10)
    //             Rectangle()
    //                 .fill(Color.DesignSystem.descriptions)
    //                 .frame(height: 2) // vagy más érték
    //         }
    //     }
    // }

// MARK: - SearchHeader
struct SearchHeader2: View {
    @Binding var searchText: String
    @Binding var showFilters: Bool
    @State private var selectedScope: SearchScope = .nearby
    @State private var isSearching = false
    @State private var filterScale: CGFloat = 1.0
    
    enum SearchScope {
        case nearby, nationwide
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Keresés")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                    
                    TextField(NSLocalizedString("search_placeholder", comment: ""), text: $searchText)
                        .onTapGesture {
                            withAnimation {
                                isSearching = true
                            }
                        }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        showFilters.toggle()
                        filterScale = 0.8
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                filterScale = 1.0
                            }
                        }
                    }
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.DesignSystem.descriptions)
                }
                
                .padding(.trailing, 8)
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                ForEach([SearchScope.nearby, .nationwide], id: \.self) { scope in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedScope = scope
                        }
                    }) {
                        Text(scope == .nearby ? "Környéken" : "Országszerte")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedScope == scope ? Color.black : Color.clear)
                            )
                            
                            .foregroundColor(selectedScope == scope ? .yellow : .black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - FilterView
struct FilterView2: View {
    @Environment(\.dismiss) var dismiss
    @Binding var filters: SearchFilters
    @State private var selectedLocation: String = ""
    @State private var selectedAvailability: String = ""
    @State private var savedFilters: [SearchFilters] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text(NSLocalizedString("category", comment: ""))
                        .font(.custom("Jellee", size: 24))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(.top, 10)
                ) {
                    VStack(spacing: 0) {
                        ForEach(SkillCategory.allCases, id: \.self) { category in
                            Toggle(
                                NSLocalizedString(category.rawValue, comment: ""),
                                isOn: Binding(
                                    get: { filters.selectedCategories.contains(category) },
                                    set: { isSelected in
                                        if isSelected {
                                            filters.selectedCategories.insert(category)
                                        } else {
                                            filters.selectedCategories.remove(category)
                                        }
                                    }
                                )
                            )
                            .foregroundColor(.black)
                            .underlineTextField()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .font(.custom("Lexend", size: 18))
                            .accentColor(.DesignSystem.fokekszin)
                            
                            if category != SkillCategory.allCases.last {
                                Divider()
                                    .background(Color.DesignSystem.fokekszin)
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(4)
                }
                
                
                
                
                Section(header:Text(NSLocalizedString("min_rating", comment:"" ))
                    .font(.custom("Jellee", size:24))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .padding(.top,10)
                ) {
                    VStack {
                        Toggle(NSLocalizedString("set_rating", comment: ""), isOn: Binding(
                            get: { filters.minimumRating > 0 },
                            set: { isSelected in
                                if !isSelected {
                                    filters.minimumRating = 0
                                } else {
                                    filters.minimumRating = 2.5
                                }
                            }
                        ))
                        .font(.custom("Lexend", size: 18))
                        .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
                        .foregroundColor(.black)
                        .underlineTextField()

                        
                        if filters.minimumRating > 0 {
                            Slider(value: $filters.minimumRating, in: 0...5, step: 0.5)
                                .accentColor(.DesignSystem.fokekszin) // A csúszka színe kék lesz
                                .cornerRadius(20)

                            
                            HStack{
                                Text(
                                    String(
                                        format: NSLocalizedString("min_rating", comment: "Minimum rating label"),
                                    )
                                )
                                .font(.custom("Lexend", size: 16))

                                
                                Spacer()
                                
                                Text(String(format: NSLocalizedString("%.1f", comment: "Label for minimum rating filter"),
                                           filters.minimumRating))
                                    
                                
                                    .font(.custom("Lexend", size: 16))
                            }

                        }
                        
                    }
                    
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .listRowBackground(Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
                    .foregroundColor(.DesignSystem.fokekszin)
                    .font(.custom("Lexend", size: 18))
                    .accentColor(.DesignSystem.fokekszin)
            }
            .listRowInsets(EdgeInsets()) // Eltávolítja a default paddingot
            .padding(4)
            .font(.custom("Lexend", size: 18))
                
                
                
                Section(header:Text(NSLocalizedString("max_price", comment:"" ))
                    .font(.custom("Jellee", size:24))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .padding(.top,10)
) {
                    VStack {
                        Toggle(NSLocalizedString("set_price", comment: "Picker title for availability options"), isOn: Binding(
                            get: { filters.maxPrice != nil },
                            set: { if !$0 { filters.maxPrice = nil } else { filters.maxPrice = 10000 } }
                        ))
                        .font(.custom("Lexend", size: 18))
                        .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
                        .foregroundColor(.black)
                        .underlineTextField()

                        if filters.maxPrice != nil {
                            Slider(
                                value: Binding(
                                    get: { filters.maxPrice ?? 10000 },
                                    set: { filters.maxPrice = $0 }
                                ),
                                in: 1000...100000,
                                step: 1000
                            )
                            .accentColor(.DesignSystem.fokekszin) // A csúszka színe kék lesz
                            .cornerRadius(20)
                            
                            HStack{
                                Text(
                                    String(
                                        format: NSLocalizedString("max_price", comment: "Label for maximum price filter"),
                                        Int(filters.maxPrice ?? 0)
                                    )
                                )
                                .font(.custom("Lexend", size: 16))

                                
                                Spacer()
                                
                                Text(
                                    String(
                                        format: NSLocalizedString("%d Ft", comment: "Label for maximum price filter"),
                                        Int(filters.maxPrice ?? 0)
                                    )
                                )
                                    .font(.custom("Lexend", size: 16))
                            }
                        }
                    }
                    
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .listRowBackground(Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
                    .foregroundColor(.DesignSystem.fokekszin)
                    .font(.custom("Lexend", size: 18))
                    .accentColor(.DesignSystem.fokekszin)
            }
            .listRowInsets(EdgeInsets()) // Eltávolítja a default paddingot
            .padding(4)
            .font(.custom("Lexend", size: 18))
                
                
                Section(
                    header: Text(NSLocalizedString("location", comment: ""))
                        .font(.custom("Jellee", size: 24))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(.top, 10)
                ) {
                    TextField(NSLocalizedString("city_or_region", comment: "Picker title for availability options"), text: $selectedLocation)
                        .foregroundColor(.black)
                        .underlineTextField()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .listRowBackground(Color.clear)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                        )
                        .foregroundColor(.DesignSystem.fokekszin)
                        .font(.custom("Lexend", size: 18))
                        .accentColor(.DesignSystem.fokekszin)
                }
                .listRowInsets(EdgeInsets()) // Eltávolítja a default paddingot
                .padding(4)
                .font(.custom("Lexend", size: 18))
                

                
                Section(header:Text(NSLocalizedString("availability", comment:"" ))
                    .font(.custom("Jellee", size:24))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .padding(.top,10)
                )
                {
                    Picker(NSLocalizedString("Availability:", comment: "Picker title for availability options"),
                          selection: $selectedAvailability) {
                        Text(NSLocalizedString("Immediately", comment: "Availability option")).tag("azonnal")
                        Text(NSLocalizedString("Within 1 day", comment: "Availability option")).tag("1_nap")
                        Text(NSLocalizedString("In 1 week", comment: "Availability option")).tag("1_het")
                    }
                          .foregroundColor(.black)
                          .underlineTextField()
                          .padding(.horizontal, 16)
                          .padding(.vertical, 14)
                          .listRowBackground(Color.clear)
                          .background(
                              RoundedRectangle(cornerRadius: 20)
                                  .fill(Color.white)
                          )
                          .overlay(
                              RoundedRectangle(cornerRadius: 20)
                                  .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                          )
                          .foregroundColor(.DesignSystem.fokekszin)
                          .font(.custom("Lexend", size: 18))
                          .accentColor(.DesignSystem.fokekszin)
                  }
                  .listRowInsets(EdgeInsets()) // Eltávolítja a default paddingot
                  .padding(4)
                  .font(.custom("Lexend", size: 18))
                
                            }
            }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("reset", comment: ""))
 {
                    filters = SearchFilters()
                    selectedLocation = ""
                                            selectedAvailability = ""
                }
            }
            
        }
            

        }
    
    }

struct NotificationsSection4: View {
    @Environment(\.dismiss) var dismiss
    @Binding var filters: SearchFilters
    @State private var selectedLocation: String = ""
    @State private var selectedAvailability: String = ""
    @State private var savedFilters: [SearchFilters] = []
    
    var body: some View {
        ForEach(SkillCategory.allCases, id: \.self) { category in
            Toggle(category.rawValue, isOn: Binding(
                get: { filters.selectedCategories.contains(category) },
                set: { isSelected in
                    if isSelected {
                        filters.selectedCategories.insert(category)
                    } else {
                        filters.selectedCategories.remove(category)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
            .font(.custom("OrelegaOne-Regular", size: 20))
        }
    }
}
// MARK: - Segédstruktúrák
struct Szekcio2: View {
    let title: String
//    @ObservedObject var viewModel: SettingsViewModel2
    
    var body: some View {
        Text(title)
            .font(.custom("OrelegaOne-Regular", size: 20))
//            .foregroundColor(viewModel.isDarkMode ? Color.white : Color.black) // Dinamikus színváltás
            .padding(.top, 10)
    }
}

struct OvalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(LinearGradient(gradient: Gradient(colors: [Color.orange, Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(20)
            .shadow(color: .gray, radius: 10)
    }
}

extension Color {
    static let darkPink = Color(red: 208 / 255, green: 45 / 255, blue: 208 / 255)
}
extension View {
    func underlineTextField() -> some View {
        self
            .padding(.vertical, 10)
            .overlay(Rectangle().frame(height: 2).padding(.top, 35))
            .foregroundColor(.DesignSystem.descriptions)
    }
}

// MARK: - ServiceCreationPopup
struct ServiceCreationPopup2: View {
    @State private var showingProfile = false
//    @ObservedObject var viewModel: SettingsViewModel3 // Így kapja meg
    
    @EnvironmentObject private var userManager: UserManager
    @Binding var serviceName: String
    @Binding var serviceDescription: String
    @Binding var serviceRating: Double
    @Binding var serviceReviewCount: Int
    @Binding var servicePrice: Double
    @Binding var serviceLocation: String
    @Binding var serviceSkills: [String]
    @Binding var serviceMediaURLs: [URL]
    @Binding var serviceType: TypeofService
    @Binding var isPremium: Bool
    let onCreate: (Service) -> Void
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var calendarManager = CalendarManager()
    @State private var selectedCategory: SkillCategory = .technology
    @State private var selectedFizetesiMod: FizetesiMod = .bankkartya
    @State private var selectedSkills: Set<String> = []
    @State private var selectedWeekDay = WeekDay.monday
    @State private var showingTimeSelector = false
    @State internal var protectionFee: Double = 0
    @State private var calendarManagerRef: CalendarManager?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showPricePopup = false
    @State private var isFetchingLocation = false // ← EZT ADD HOOZZÁ
    @State private var selectedLocationOption: LocationSharingOption = .precise
    @State private var selectedCountry = ""
    @State private var selectedCity = ""
    @State private var selectedDistrict = ""
    
    @State private var showingMapPicker = false
        @StateObject private var locationManager = LocationManager()
        @State private var selectedCoordinate: CLLocationCoordinate2D?
        @State private var selectedAddress = ""

    // Computed property for total amount
    internal var totalAmount: Double {
        return servicePrice + protectionFee
    }


    enum LocationSharingOption {
        case precise // Pontos cím (utcával)
        case areaOnly // Csak terület (ország, város, kerület)
    }


        // MARK: - Helyválasztó Section - Beépített SwiftUI megoldásokkal
//        private func locationSection() -> some View {
//            Section(header: Text(NSLocalizedString("location", comment: ""))
//                .font(.custom("OrelegaOne-Regular", size: 20))
//                .foregroundColor(.DesignSystem.descriptions)
//                .background(Color.DesignSystem.fokekszin)
//                .cornerRadius(10)
//            ) {
//                VStack(alignment: .leading, spacing: 12) {
//
//                    // Jelenlegi hely megjelenítése
//                    if !serviceLocation.isEmpty {
//                        HStack {
//                            Image(systemName: "mappin.circle.fill")
//                                .foregroundColor(.DesignSystem.fokekszin)
//                                .font(.title2)
//                            VStack(alignment: .leading) {
//                                Text(NSLocalizedString("selected_location", comment: ""))
//                                    .font(.custom("OrelegaOne-Regular", size: 14))
//                                    .foregroundColor(.gray)
//                                Text(serviceLocation)
//                                    .font(.custom("OrelegaOne-Regular", size: 16))
//                                    .foregroundColor(.black)
//                            }
//                            Spacer()
//                        }
//                        .padding()
//                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
//                        .cornerRadius(10)
//                    }
//
//                    // GPS helymeghatározás gomb
//                    Button(action: useCurrentLocation) {
//                        HStack {
//                            Image(systemName: "location.fill")
//                                .foregroundColor(.white)
//                            Text(NSLocalizedString("use_current_location", comment: ""))
//                                .font(.custom("OrelegaOne-Regular", size: 16))
//                                .foregroundColor(.white)
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.DesignSystem.fokekszin)
//                        .cornerRadius(10)
//                    }
//
//                    // Térkép helyválasztó
//                    Button(action: { showingMapPicker = true }) {
//                        HStack {
//                            Image(systemName: "map.fill")
//                                .foregroundColor(.white)
//                            Text(NSLocalizedString("select_on_map", comment: ""))
//                                .font(.custom("OrelegaOne-Regular", size: 16))
//                                .foregroundColor(.white)
//                            Spacer()
//                            Image(systemName: "chevron.right")
//                                .foregroundColor(.white)
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.DesignSystem.descriptions)
//                        .cornerRadius(10)
//                    }
//                    .sheet(isPresented: $showingMapPicker) {
//                        MapLocationPicker(selectedCoordinate: $selectedCoordinate, selectedAddress: //$serviceLocation)
//                    }
//
//                    // Manuális cím megadása (opcionális)
//                    Button(action: {
//                        // Mutassunk egy alert-et a cím manuális megadásához
//                        showManualAddressInput()
//                    }) {
//                        HStack {
//                            Image(systemName: "pencil")
//                                .foregroundColor(.DesignSystem.descriptions)
//                            Text(NSLocalizedString("enter_address_manually", comment: ""))
//                                .font(.custom("OrelegaOne-Regular", size: 16))
//                                .foregroundColor(.DesignSystem.descriptions)
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.white)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 10)
//                                .stroke(Color.DesignSystem.descriptions, lineWidth: 1)
//                        )
//                    }
//                }
//            }
//        }
    




    // MARK: - Új rész: Prémium Toggle
    private func premiumToggleSection() -> some View {
        Section(header:Text(NSLocalizedString("premium_service", comment:"" ))
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
            .padding(.top, 10))
        {
            Toggle(NSLocalizedString("premium_service", comment: "Toggle for premium service"),
                   isOn: $isPremium)
            
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .listRowBackground(Color.clear)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
            )
            .foregroundColor(.DesignSystem.fokekszin)
            .font(.custom("Lexend", size: 18))
            .accentColor(.DesignSystem.fokekszin)
            .listRowInsets(EdgeInsets())
            .padding(4)
            .foregroundStyle(
                LinearGradient(
                    colors: [.red, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.fokekszin))
                .underlineTextField()

        }
    }
    struct SectionWithBackground2<Content: View, Header: View>: View {
        let content: Content
        let header: Header
        
        init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
            self.content = content()
            self.header = header()
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal)
                    .padding(.top, 10)
                ZStack {
                    Rectangle()
                        .fill(Color.DesignSystem.fokekszin)
                        .cornerRadius(10)
                        .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
                    content
                        .padding()
                }
            }
        }
    }
    
    // MARK: - Helyválasztó Section - Precíz automatikus helymeghatározással
    private func locationSection() -> some View {
        Section(header: Text(NSLocalizedString("location", comment: ""))
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
            .padding(.top, 10)
        ) {
            // ÚJ: Helymegosztási opció választó
            VStack(alignment: .leading, spacing: 12) {
                Text("Helymegosztás típusa")
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(.black)
                    .padding(.bottom, 8)
                
                Picker("Helymegosztás", selection: $selectedLocationOption) {
                    Text("Pontos cím").tag(LocationSharingOption.precise)
                    Text("Csak terület").tag(LocationSharingOption.areaOnly)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom, 8)
                
                Text(selectedLocationOption == .precise ?
                     "Az utcácím is látható lesz!" :
                     "Csak város/kerület látható, pontos cím rejtve")
                    .font(.custom("Lexend", size: 15))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Meglévő helymeghatározás rész - csak pontos cím esetén
            if selectedLocationOption == .precise {
                preciseLocationContent()
            } else {
                areaOnlyLocationContent()
            }
            
        }
        
    }
    private func preciseLocationContent() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Automatikus helymeghatározás állapota
            if isFetchingLocation {
                HStack {
                    ProgressView()
                        .tint(.DesignSystem.fokekszin)
                    VStack(alignment: .leading) {
                        Text("Helymeghatározás...")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.DesignSystem.fokekszin)
                        Text("Kérjük várjon, pontosan meghatározzuk a helyét")
                            .font(.custom("Lexend", size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Jelenlegi hely megjelenítése
            if !serviceLocation.isEmpty && !isFetchingLocation {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.DesignSystem.fokekszin)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Kiválasztott hely:")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.gray)
                        Text(serviceLocation)
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.black)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(action: {
                        serviceLocation = ""
                        selectedCoordinate = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                .cornerRadius(20)
            }
            
            // Automatikus helymeghatározás gomb
            Button(action: {
                fetchPreciseLocation()
            }) {
                HStack {
 
                    VStack(alignment: .leading) {
                        Text("Jelenlegi helyem használata")
                            .font(.custom("Jellee", size: 16))
                            .foregroundColor(.white)
                        Text("Pontos GPS helymeghatározás")
                            .font(.custom("Lexend", size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    if isFetchingLocation {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(
                    gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .cornerRadius(20)
            }
            .disabled(isFetchingLocation)
            
            // Választási lehetőség
            if !isFetchingLocation {

                
                // Térkép helyválasztó
//                Button(action: { showingMapPicker = true }) {
//                   HStack {
//                       Image(systemName: "map.fill")
//                           .foregroundColor(.white)
//                       Text("Hely kiválasztása a térképről")
//                           .font(.custom("OrelegaOne-Regular", size: 16))
//                           .foregroundColor(.white)
//                       Spacer()
//                       Image(systemName: "chevron.right")
//                           .foregroundColor(.white)
//                   }
//                   .frame(maxWidth: .infinity)
//                   .padding()
//                   .background(Color.DesignSystem.descriptions)
//                   .cornerRadius(10)
//               }
                
                // Manuális cím megadása
                Button(action: showManualAddressInput) {
                    HStack {
                        Image(systemName: "text.pad.header")
                            .foregroundColor(.DesignSystem.descriptions)
                        Text("Cím beírása kézzel")
                            .font(.custom("Jellee", size: 16))
                            .foregroundColor(.DesignSystem.descriptions)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.DesignSystem.descriptions)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.descriptions, lineWidth: 3)
                    )
                }
            }
        }
    }
    
    private func areaOnlyLocationContent() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add meg a szolgáltatás helyét (pontos cím nélkül)")
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            // Ország választó
            VStack(alignment: .leading, spacing: 8) {
                Text("Ország")
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.black)
                
                TextField("Pl. Magyarország", text: $selectedCountry)
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                    )
            }
            
            // Város választó
            VStack(alignment: .leading, spacing: 8) {
                Text("Város")
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.black)
                
                TextField("Pl. Budapest", text: $selectedCity)
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                    )
            }
            
            // Kerület/keresztnév (opcionális)
            VStack(alignment: .leading, spacing: 8) {
                Text("Kerület/rész (opcionális)")
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.black)
                
                TextField("Pl. V. kerület, vagy Újlipótváros", text: $selectedDistrict)
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 3)
                    )
            }
            
            // Automatikus kitöltés gomb
            Button(action: {
                fillCurrentArea()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.white)
                    Text("Automatikus kitöltés")
                        .font(.custom("Jellee", size: 16))
                        .foregroundColor(.white)
                    Spacer()
                    if isFetchingLocation {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.DesignSystem.fokekszin)
                .cornerRadius(20)
            }
            .disabled(isFetchingLocation)
            
            // Előnézet
            if !selectedCountry.isEmpty || !selectedCity.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Előnézet:")
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(.gray)
                    Text(formatAreaLocation())
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Precíz Location Management
    private func showManualAddressInput() {
         let alert = UIAlertController(
             title: NSLocalizedString("enter_address", comment: ""),
             message: NSLocalizedString("enter_full_address", comment: ""),
             preferredStyle: .alert
         )
         
         alert.addTextField { textField in
             textField.placeholder = NSLocalizedString("street_city_country", comment: "")
             textField.text = serviceLocation
         }
         
         alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
         alert.addAction(UIAlertAction(title: NSLocalizedString("save", comment: ""), style: .default) { _ in
             if let textField = alert.textFields?.first, let text = textField.text, !text.isEmpty {
                 serviceLocation = text
             }
         })
         
         // Present the alert
         if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootViewController = windowScene.windows.first?.rootViewController {
             rootViewController.present(alert, animated: true)
         }
     }
    // ÚJ: Automatikus terület kitöltése GPS alapján
    private func fillCurrentArea() {
        isFetchingLocation = true
        
        locationManager.requestLocation { location, error in
            DispatchQueue.main.async {
                self.isFetchingLocation = false
                
                if let error = error {
                    print("❌ Hiba a terület meghatározás során: \(error.localizedDescription)")
                    return
                }
                
                guard let location = location else {
                    return
                }
                
                // Geocoding csak ország/város/kerület információkért
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    DispatchQueue.main.async {
                        if let placemark = placemarks?.first {
                            // Csak a területi információkat tároljuk
                            self.selectedCountry = placemark.country ?? ""
                            self.selectedCity = placemark.locality ?? ""
                            self.selectedDistrict = placemark.subLocality ?? ""
                            
                            // Frissítjük a serviceLocation-t is a formázott verzióval
                            self.serviceLocation = self.formatAreaLocation()
                        }
                    }
                }
            }
        }
    }

    // ÚJ: Területi információk formázása
    private func formatAreaLocation() -> String {
        var components: [String] = []
        
        if !selectedCountry.isEmpty {
            components.append(selectedCountry)
        }
        if !selectedCity.isEmpty {
            components.append(selectedCity)
        }
        if !selectedDistrict.isEmpty {
            components.append(selectedDistrict)
        }
        
        return components.joined(separator: ", ")
    }
    
    private func fetchPreciseLocation() {
        isFetchingLocation = true
        print("📍 Helymeghatározás indítása...")
        
        // JAVÍTVA: Távolítsd el a felesleges guard let self = self-t
        locationManager.requestLocation { location, error in
            DispatchQueue.main.async {
                self.isFetchingLocation = false
                
                if let error = error {
                    print("❌ Hiba a helymeghatározás során: \(error.localizedDescription)")
                    self.showLocationError(message: "Nem sikerült meghatározni a helyét. Kérjük, ellenőrizze a GPS beállításokat.")
                    return
                }
                
                guard let location = location else {
                    print("❌ Nincs helyadat")
                    self.showLocationError(message: "Nem sikerült meghatározni a helyét.")
                    return
                }
                
                print("📍 Helyadat megérkezett: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                
                // Precíz geocoding a pontos címhez
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Geocoding hiba: \(error.localizedDescription)")
                            // Ha geocoding nem sikerül, legalább a koordinátákat használjuk
                            self.serviceLocation = String(format: "GPS: %.6f, %.6f",
                                                        location.coordinate.latitude,
                                                        location.coordinate.longitude)
                            self.selectedCoordinate = location.coordinate
                            return
                        }
                        
                        guard let placemark = placemarks?.first else {
                            self.serviceLocation = String(format: "GPS: %.6f, %.6f",
                                                        location.coordinate.latitude,
                                                        location.coordinate.longitude)
                            self.selectedCoordinate = location.coordinate
                            return
                        }
                        
                        // Részletes cím összeállítása
                        var addressComponents: [String] = []
                        
                        // Utca, házszám
                        if let thoroughfare = placemark.thoroughfare {
                            if let subThoroughfare = placemark.subThoroughfare {
                                addressComponents.append("\(thoroughfare) \(subThoroughfare)")
                            } else {
                                addressComponents.append(thoroughfare)
                            }
                        }
                        
                        // Városrész/kerület
                        if let subLocality = placemark.subLocality {
                            addressComponents.append(subLocality)
                        }
                        
                        // Város
                        if let locality = placemark.locality {
                            addressComponents.append(locality)
                        }
                        
                        // Megye/régió
                        if let administrativeArea = placemark.administrativeArea {
                            if administrativeArea != placemark.locality {
                                addressComponents.append(administrativeArea)
                            }
                        }
                        
                        // Irányítószám
                        if let postalCode = placemark.postalCode {
                            addressComponents.append(postalCode)
                        }
                        
                        // Ország
                        if let country = placemark.country {
                            addressComponents.append(country)
                        }
                        
                        if addressComponents.isEmpty {
                            // Ha egyik sem sikerült, koordinátákat használjuk
                            self.serviceLocation = String(format: "GPS: %.6f, %.6f",
                                                        location.coordinate.latitude,
                                                        location.coordinate.longitude)
                        } else {
                            // Szép, olvasható cím formázása
                            self.serviceLocation = addressComponents.joined(separator: ", ")
                        }
                        
                        self.selectedCoordinate = location.coordinate
                        print("✅ Hely sikeresen meghatározva: \(self.serviceLocation)")
                    }
                }
            }
        }
    }

    private func showLocationError(message: String) {
        let alert = UIAlertController(
            title: "Helymeghatározási hiba",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Beállítások", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Próbáld újra", style: .default) { [self] _ in
            self.fetchPreciseLocation()
        })
        
        alert.addAction(UIAlertAction(title: "Rendben", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    private func useCurrentLocation() {
        fetchPreciseLocation()
    }

    private func setupLocation() {
        // Inicializáláskor automatikusan megpróbáljuk lekérni a helyet
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if serviceLocation.isEmpty {
                fetchPreciseLocation()
            }
        }
    }

    private func reverseGeocodeLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    selectedAddress = formatAddress(from: placemark)
                    serviceLocation = selectedAddress
                }
            }
        }
    }

    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    // MARK: - Szolgáltatás létrehozása
    // ServiceCreationPopup2.swift - createService metódus
    private func createService() {
        let user = userManager.currentUser
        
        serviceSkills = Array(selectedSkills)
        let serviceId = UUID()
        
        let finalLocation: String
        if selectedLocationOption == .precise {
            finalLocation = serviceLocation
        } else {
            finalLocation = formatAreaLocation()
            if finalLocation.isEmpty {
                alertMessage = "Kérjük, add meg a szolgáltatás helyét"
                showingAlert = true
                return
            }
        }
        
        print("📍 Service létrehozva helyadattal: \(finalLocation)") // DEBUG
        
        let availability = ServiceAvailability(
            serviceId: serviceId,
            weeklySchedule: calendarManager.weeklySchedule,
            exceptions: calendarManager.exceptions
        )
        
        let newService = Service(
            advertiser: user ?? .preview,
            name: serviceName,
            description: serviceDescription,
            rating: 0.0,
            reviewCount: 0,
            price: totalAmount,
            location: finalLocation, // HELYADAT ÁTVITEL
            skills: serviceSkills,
            mediaURLs: serviceMediaURLs,
            availability: availability,
            typeofService: .other,
            serviceOption: isPremium ? .premium : .free
        )
        
        onCreate(newService)
        presentationMode.wrappedValue.dismiss()
    }
    var body: some View {
        NavigationView {
            
            Form {
                
                serviceDetailsSection()
                locationSection()
                categorySection()
                skillsSection()
                availabilitySection()
                FizetesiModsection()
                premiumToggleSection()
                createButtonSection()
            }

            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: ""))
                    {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing))
                    .font(.custom("Lexend", size: 20))
                }
            }
            .sheet(isPresented: $showingTimeSelector) {
                TimeRangeSelectorView2(weekDay: selectedWeekDay, calendarManager: calendarManager)
            }
            .alert("Figyelem", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            
            .onAppear {
                        // Automatikusan megpróbálja lekérni a helyet, ha még nincs beállítva
                        if serviceLocation.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                fetchPreciseLocation()
                            }
                        }
                    }
        }
    }

    private func serviceDetailsSection() -> some View {
        Section(header:Text(NSLocalizedString("service_details", comment:"" ))
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
            .padding(.top, 10)
        )
        
        {
            VStack{

            VStack(alignment: .leading, spacing: 8) {
                Text("Létrehozás, mint:")
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.gray)
                
                HStack {
                    
                    Button(action: { showingProfile = true }) {
                                        ProfileImage(size: 50, showEditButton: false)
                                    }
                        .foregroundColor(.DesignSystem.fokekszin)
                        .font(.custom("Lexend", size: 18))

                    
                    Text(userManager.currentUser?.name ?? "Nincs bejelentkezve")
                        .font(.custom("Lexend", size: 18))
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.bottom, 8)
            
            TextField("service_name", text: $serviceName)
                .font(.custom("Lexend", size: 20))
                .foregroundColor(.black)
                .underlineTextField()
            
            
            
            TextField("service_description", text: $serviceDescription)
                .font(.custom("Lexend", size: 20))
                .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
                .foregroundColor(.black)
                .underlineTextField()
            
            
            
            
            // Price section with protection fee
            VStack(alignment: .leading, spacing: 8) {
                
                HStack{
                    TextField(NSLocalizedString("price_from", comment: "TextField placeholder for minimum price in Hungarian Forints"),
                              text: Binding<String>(
                                get: { String(Int(servicePrice)) },
                                set: {
                                    let input = Double(Int($0) ?? 0)
                                    if input > 10_000_000 {
                                        servicePrice = 10_000_000
                                    } else {
                                        servicePrice = input
                                    }
                                    protectionFee = calculateProtectionFee(for: servicePrice)
                                }
                              ))
                    .keyboardType(.numberPad)
                    .font(.custom("Lexend", size: 18))
                    .foregroundColor(.black)
                    .underlineTextField()
                    
                    
                    Button {
                        showPricePopup = true
                    } label: {
                        
                        HStack{
                            Image(systemName: "questionmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 25)
                                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .top, endPoint: .bottom))
                                .background(.white)
                                .cornerRadius(40)
                                .symbolEffect(.bounce.down.wholeSymbol, options: .nonRepeating)
                                .padding(.horizontal, 5)
                        }
                    }
                    .padding()
                    .sheet(isPresented: $showPricePopup) {
                        PricePopupView(
                            servicePrice: $servicePrice,
                            protectionFee: $protectionFee,
                            isPresented: $showPricePopup,
                            calculateProtectionFee: calculateProtectionFee
                        )
                    }
                    
                }
                if servicePrice > 10_000_000 {
                    Text("Maximum 10 millió forint lehet a szolgáltatás ára")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                //                if servicePrice > 0 {
                //                    Text("Eredeti ár: \(Int(servicePrice)) Ft")
                //                        .foregroundColor(.gray)
                //                        .font(.custom("Lexend", size: 16))
                //
                //                    Text("(Ennyit kap ebből a munkavállaló)")
                //                        .foregroundColor(.gray)
                //                        .font(.custom("OrelegaOne-Regular", size: 14))
                //                    Text("+Vásárlóvédelmi díj: \(Int(protectionFee)) Ft //(Munkakeresőt terheli)")
                //                        .foregroundColor(.gray)
                //                        .font(.custom("OrelegaOne-Regular", size: 14))
                //                    Text("Vásárlóvédelmi díjjal: \(Int(totalAmount)) Ft")
                //                        .foregroundColor(.blue)
                //                        .fontWeight(.bold)
                //                }
            }
            
            TextField(NSLocalizedString("location", comment:"" ), text: $serviceLocation)
            
                .font(.custom("Lexend", size: 18))
                .foregroundColor(.black)
                .underlineTextField()
        }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .font(.custom("Lexend", size: 18))
            .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
            .foregroundStyle(.black)
            .foregroundColor(.black)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
            )
            .listRowInsets(EdgeInsets())
            .padding(4)
        }
        
        
        
    }
    
    
    

    private func categorySection() -> some View {
        Section(header:Text(NSLocalizedString("category", comment:"" ))
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
            .padding(.top, 10)
        ) {
                Picker(NSLocalizedString("category", comment: "Picker label for categories"),selection: $selectedCategory)
            
            {
                ForEach(SkillCategory.allCases, id: \.self) { category in
                    Text(NSLocalizedString(category.rawValue, comment: "Category option"))
                        .tag(category)
                }
                
                
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .font(.custom("Lexend", size: 18))
            .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
            .foregroundStyle(.black)
            .foregroundColor(.black)
            .underlineTextField()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
            )
            .listRowInsets(EdgeInsets())
            .padding(4)
            
                
                
        }
            .foregroundColor(.black)
            .font(.custom("Lexend", size: 18))
        


    }

    private func skillsSection() -> some View {
        Section(header: Text(NSLocalizedString("skills", comment: ""))
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
            .padding(.top, 10)) {
                
                VStack(spacing: 0) {
                    
                    if let skills = skillsByCategory[selectedCategory] {
                        ForEach(skills, id: \.self) { skillKey in
                            Toggle(NSLocalizedString(skillKey, comment: ""), isOn: Binding(
                                get: { selectedSkills.contains(skillKey) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedSkills.insert(skillKey)
                                    } else {
                                        selectedSkills.remove(skillKey)
                                    }
                                }
                            ))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .font(.custom("Lexend", size: 18))
                            .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
                            .foregroundStyle(.black)
                            .underlineTextField()

                        }
                        
                    } else {
                        Text(NSLocalizedString("noSkillsInCategory", comment: ""))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                        )
                )
                .listRowInsets(EdgeInsets())
                .padding(4)
                
                
            }
        
    }


    private func availabilitySection() -> some View {
        Section(header: Text(NSLocalizedString("available_times", comment: ""))
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
            .padding(.top, 10)
        ) {
            
            VStack{
                ForEach(WeekDay.allCases, id: \.self) { day in
                    DisclosureGroup(day.name) {
                        if let ranges = calendarManager.weeklySchedule[day] {
                            ForEach(ranges) { range in
                                HStack {
                                    Text(formatTimeRange(range))
                                    Spacer()
                                    Button(action: {
                                        calendarManager.removeTimeRange(range, from: day)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedWeekDay = day
                            showingTimeSelector = true
                        }) {
                            Label(NSLocalizedString("add_time", comment: "Label for adding an appointment"),
                                  systemImage: "plus.circle")
                            .foregroundColor(.black)
                            .font(.custom("OrelegaOne-Regular", size: 18))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .font(.custom("Lexend", size: 18))
                    .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
                    .foregroundStyle(.black)
                }
                .foregroundColor(.black)
                .underlineTextField()
            }
        
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                )
        )
        .listRowInsets(EdgeInsets())
        .padding(4)
        }
    }
    private func FizetesiModsection() -> some View {
        Section(header:Text(NSLocalizedString("Payment-metod", comment:"" ))
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
            .padding(.top, 10)
        ) {
                Picker(NSLocalizedString("Payment Method", comment: "Picker label for categories"),
                                   selection: $selectedFizetesiMod)
            
            
            
            
            {
                ForEach(FizetesiMod.allCases, id: \.self) { category in
                    Text(NSLocalizedString(category.rawValue, comment: "Category option"))
                                            .tag(category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .font(.custom("Lexend", size: 18))
            .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
            .foregroundStyle(.black)
            .foregroundColor(.black)
            .underlineTextField()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
            )
            .listRowInsets(EdgeInsets())
            .padding(4)
                
                
        }
            .foregroundColor(.black)
            

    }
    private func createButtonSection() -> some View {
        Button(action: createService) {
            HStack {

                Text(NSLocalizedString("create_service", comment:"" ))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce.down.wholeSymbol, options: .nonRepeating)
                    .font(.custom("Jellee", size: 22))
            }
            .padding(16)
            .padding(.horizontal,10)
            .background(LinearGradient(
                gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                startPoint: .leading,
                endPoint: .trailing
            ))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 4)
            )
            .cornerRadius(20)
            .shadow(color: Color.DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
            .padding(.vertical, 30)
        }
        .listRowBackground(Color.clear)
        .disabled(!isFormValid)
        .frame(maxWidth: .infinity) // Széles keret
        .multilineTextAlignment(.center) // Szöveg középre igazítása
    }

    private var isFormValid: Bool {
        !serviceName.isEmpty &&
        !serviceDescription.isEmpty &&
        servicePrice > 0 &&
        // ÚJ: Hely ellenőrzése a kiválasztott opció alapján
        ((selectedLocationOption == .precise && !serviceLocation.isEmpty) ||
         (selectedLocationOption == .areaOnly && (!selectedCity.isEmpty || !selectedCountry.isEmpty)))
    }

    private func formatTimeRange(_ range: TimeRange) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }
    
    
}


// Egyszerűsített WorkCard struktúra
struct WorkCard2: View {
    let work: WorkData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(work.title)
                .font(.headline)
                
            
            Text(work.employerName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(Int(work.wage)) Ft")
                .font(.title3)
                .foregroundColor(.yellow)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}


struct PricePopupView: View {
    @Binding var servicePrice: Double
    @Binding var protectionFee: Double
    @Binding var isPresented: Bool
    
    let calculateProtectionFee: (Double) -> Double
    
    private var totalAmount: Double {
        return servicePrice + protectionFee
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Fejléc
                Text(NSLocalizedString("Árkalkuláció", comment:"" ))
                    .font(.custom("Jellee", size: 30))
                    .foregroundStyle(.black)
                    .padding(.bottom, 4)
                
                // Szövegmező
                VStack(alignment: .leading, spacing: 8) {
                    TextField(NSLocalizedString("price_from", comment: "TextField placeholder for minimum price in Hungarian Forints"),
                              text: Binding<String>(
                        get: { String(Int(servicePrice)) },
                        set: {
                            let input = Double(Int($0) ?? 0)
                            if input > 10_000_000 {
                                servicePrice = 10_000_000
                            } else {
                                servicePrice = input
                            }
                            protectionFee = calculateProtectionFee(servicePrice)
                        }
                    ))
                    .keyboardType(.numberPad)
                    .font(.custom("Lexend", size: 18))
                    .foregroundColor(.black)
                    .underlineTextField()
                    .padding(.bottom, 8)
                    
                    // Hibaüzenet
                    if servicePrice > 10_000_000 {
                        Text("Maximum 10 millió forint lehet a szolgáltatás ára")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // Ár részletek
                if servicePrice > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ár részletek")
                            .font(.custom("Lexend", size: 16))
                            .foregroundStyle(.black)
                            .padding(.bottom, 4)
                        
                        HStack{
                            Text("Eredeti ár:")
                                .foregroundColor(.gray)
                                .font(.custom("Lexend", size: 16))
                            
                            Spacer()
                            
                            Text("\(Int(servicePrice)) Ft")
                                .foregroundColor(.black)
                                .font(.custom("Lexend", size: 16))
                            
                        }
//                        Text("(Ennyit kap ebből a munkavállaló)")
//                            .foregroundColor(.gray)
//                            .font(.custom("Lexend", size: 16))

                        
                        HStack{
                            Text("Munkavédelmi díj:")
                                .foregroundColor(.gray)
                                .font(.custom("Lexend", size: 16))
                            
                            Spacer()
                            
                            Text("\(Int(protectionFee)) Ft")
                                .foregroundColor(.black)
                                .font(.custom("Lexend", size: 16))
                            
                        }
                        
                        
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        
                        HStack{
                            Text("Összesen:")
                                .foregroundColor(.gray)
                                .font(.custom("Lexend", size: 20))
                            
                            Spacer()
                            
                            Text("\(Int(totalAmount)) Ft")
                                .foregroundColor(.red)
                                .font(.custom("Jellee", size: 20))
                            
                        }
                        
                    }
                    .padding()
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(20)
                }
                
                Spacer()
                
                // Mentes gomb
                Button {
                    isPresented = false
                } label: {
                    Text("Értem.")
                        .font(.custom("Lexend", size: 20))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(
                            gradient: Gradient(colors: [.indigo, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .cornerRadius(20)
                }
                .padding(.top, 20)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading:                     Button(NSLocalizedString("cancel", comment: ""))
 {
                isPresented = false
            }
                .foregroundStyle(LinearGradient(
                    gradient: Gradient(colors: [.indigo, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .font(.custom("Lexend", size: 20))
            )
            
        }
    }
}

// MARK: - User Search Card
struct UserSearchCard2: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                            Text(user.name)
                                .font(.headline)
                            
                            if user.isVerified {
                                VerifiedBadge(size: 16)
                            }
                        }
                        
            Text(user.location.city)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(String(format: "Értékelés: %.1f", user.rating))
                .font(.title3)
                .foregroundColor(.yellow)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}




    
    // MARK: - SearchView_Previews
#if DEBUG

    
    
    
struct ServiceCreationPopupPreview: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ServiceCreationPopup2(
                serviceName: .constant("Sample Service"),
                serviceDescription: .constant("This is a sample service description"),
                serviceRating: .constant(4.5),
                serviceReviewCount: .constant(10),
                servicePrice: .constant(5000),
                serviceLocation: .constant("Budapest"),
                serviceSkills: .constant(["Swift", "iOS"]),
                serviceMediaURLs: .constant([]),
                serviceType: .constant(.technology),
                isPremium: .constant(false),
                onCreate: { _ in }
            )
            .environmentObject(UserManager.shared)
        }
    }
}

// Wrapper view to show SearchView with popup open
struct SearchViewWithPopup: View {
    @State private var showPopup = true
    
    var body: some View {
        ZStack {
            SearchView2(initialSearchText: "")
                .environmentObject(UserManager.shared)
            
            // Programmatically show the popup
            .sheet(isPresented: $showPopup) {
                ServiceCreationPopup2(
                    serviceName: .constant(""),
                    serviceDescription: .constant(""),
                    serviceRating: .constant(0),
                    serviceReviewCount: .constant(0),
                    servicePrice: .constant(0),
                    serviceLocation: .constant(""),
                    serviceSkills: .constant([]),
                    serviceMediaURLs: .constant([]),
                    serviceType: .constant(.other),
                    isPremium: .constant(false),
                    onCreate: { _ in }
                )
                .environmentObject(UserManager.shared)
            }
        }
    }
}

struct SearchViewWithPopup_Previews: PreviewProvider {
    static var previews: some View {
        SearchViewWithPopup()
            .previewDisplayName("SearchView with Popup Open")
    }
}

#Preview("PricePopupView - Kitöltve") {
    PricePopupView(
        servicePrice: .constant(50000),
        protectionFee: .constant(5000),
        isPresented: .constant(true),
        calculateProtectionFee: { price in price * 0.1 }
    )
}

#endif
    
    // Remove the standalone preview variable
    // public var preview: Service { ... } should be deleted


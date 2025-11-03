import SwiftUI
import CodeScanner
import DesignSystem
internal import AVFoundation

struct WorkStartEmployeeView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var serverAuthManager = ServerAuthManager.shared
    
    @State private var showingQRScanner = false
    @State private var isLoading = false
    @State private var isLoadingActiveWork = true
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var activeWork: WorkData?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isWorkActive = false
    @State private var manualCodeInput = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 50))
                                .foregroundColor(.DesignSystem.fokekszin)
                            
                            Text("Munka Indítása")
                                .font(.custom("Jellee", size: 28))
                                .foregroundColor(.DesignSystem.fokekszin)
                            
                            Text("Szkenneld be a munkáltató által biztosított QR kódot")
                                .font(.custom("Lexend", size: 16))
                                .foregroundColor(.DesignSystem.descriptions)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 20)
                        
                        if isLoadingActiveWork {
                            loadingActiveWorkView
                        } else if isLoading {
                            loadingView
                        } else if isWorkActive, let work = activeWork {
                            activeWorkView(work: work)
                        } else {
                            inactiveWorkView
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingQRScanner) {
                CodeScannerView(
                    codeTypes: [.qr],
                    completion: handleQRScan
                )
            }
            .alert("Hiba", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadActiveWork()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    private var loadingActiveWorkView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.DesignSystem.fokekszin)
            
            Text("Aktív munka betöltése...")
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.DesignSystem.descriptions)
        }
        .frame(height: 200)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.DesignSystem.fokekszin)
            
            Text("Betöltés...")
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.DesignSystem.descriptions)
        }
        .frame(height: 200)
    }
    
    private var inactiveWorkView: some View {
        VStack(spacing: 24) {
            // QR szkennelés kártya
            VStack(spacing: 20) {
                Image(systemName: "qrcode")
                    .font(.system(size: 60))
                    .foregroundColor(.DesignSystem.fokekszin)
                
                Text("Nincs aktív munka")
                    .font(.custom("Jellee", size: 22))
                    .foregroundColor(.DesignSystem.fokekszin)
                
                Text("A munka elindításához szkenneld be a munkáltató által biztosított QR kódot")
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.DesignSystem.descriptions)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button(action: {
                    showingQRScanner = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("QR Kód Szkennelése")
                            .font(.custom("Jellee", size: 18))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.DesignSystem.fokekszin)
                    .cornerRadius(12)
                }
                
                // VAGY szeparátor
                HStack {
                    VStack { Divider() }
                    Text("VAGY")
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                    VStack { Divider() }
                }
                .padding(.vertical, 8)
                
                // Manuális kód bevitel
                VStack(alignment: .leading, spacing: 12) {
                    Text("Manuális kód bevitel")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    TextField("Add meg a munkakódot", text: $manualCodeInput)
                        .font(.custom("Lexend", size: 16))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: manualCodeInput) { newValue in
                            // Korlátozzuk a hosszt, de minden karaktert elfogadunk
                            if newValue.count > 20 {
                                manualCodeInput = String(newValue.prefix(20))
                            }
                        }
                    
                    Text("Add meg a munkáltatótól kapott kódot")
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                    
                    Button(action: {
                        startWorkWithManualCode()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "keyboard")
                            Text("Kód Ellenőrzése")
                                .font(.custom("Jellee", size: 16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(manualCodeInput.count == 8 ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(manualCodeInput.isEmpty)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // Utasítások
            VStack(alignment: .leading, spacing: 16) {
                Text("Hogyan működik?")
                    .font(.custom("Jellee", size: 20))
                    .foregroundColor(.DesignSystem.fokekszin)
                
                InstructionRow(icon: "1.circle", text: "Kérj QR kódot vagy 8 jegyű kódot a munkáltatótól")
                InstructionRow(icon: "2.circle", text: "Szkenneld be a QR kódot vagy írd be a 8 jegyű kódot")
                InstructionRow(icon: "3.circle", text: "Engedélyezd a kamera használatát (QR kód esetén)")
                InstructionRow(icon: "4.circle", text: "A munka automatikusan elindul")
            }
            .padding(20)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func activeWorkView(work: WorkData) -> some View {
        VStack(spacing: 24) {
            // Munka információk
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(work.title)
                            .font(.custom("Jellee", size: 24))
                            .foregroundColor(.DesignSystem.fokekszin)
                        
                        Text(work.employerName)
                            .font(.custom("Lexend", size: 16))
                            .foregroundColor(.DesignSystem.descriptions)
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: work.statusText)
                }
                
                Divider()
                
                // Időzítő
                VStack(spacing: 12) {
                    Text("Eltelt idő")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.descriptions)
                    
                    Text(formattedTime(elapsedTime))
                        .font(.custom("Jellee", size: 32))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .monospacedDigit()
                }
                
                Divider()
                
                // Munka részletek
                HStack(spacing: 20) {
                    InfoItem(icon: "dollarsign.circle", title: "Fizetés", value: "\(Int(work.wage)) Ft")
                    InfoItem(icon: "clock", title: "Fizetés típus", value: work.paymentType)
                }
                
                if !work.location.isEmpty {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(.DesignSystem.fokekszin)
                        Text(work.location)
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.DesignSystem.descriptions)
                        Spacer()
                    }
                }
                
                // Készségek
                if !work.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Szükséges készségek")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.DesignSystem.descriptions)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(work.skills, id: \.self) { skill in
                                    Text(skill)
                                        .font(.custom("Lexend", size: 12))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.DesignSystem.fokekszin.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // Művelet gombok
            VStack(spacing: 12) {
                Button(action: {
                    finishWork()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "stop.circle.fill")
                        Text("Munka Befejezése")
                            .font(.custom("Jellee", size: 18))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Műveletek
    
    private func loadActiveWork() {
        guard let employeeId = userManager.currentUser?.id else {
            isLoadingActiveWork = false
            return
        }
        
        Task {
            do {
                if let activeWork = try await serverAuthManager.fetchActiveWorkForEmployee(employeeId: employeeId) {
                    await MainActor.run {
                        self.activeWork = activeWork
                        self.isWorkActive = true
                        self.isLoadingActiveWork = false
                        self.startTimer()
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingActiveWork = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingActiveWork = false
                    print("❌ Aktív munka betöltési hiba: \(error)")
                }
            }
        }
    }
    
    private func handleQRScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            let qrCode = result.string
            print("📱 Beolvasott QR kód: \(qrCode)")
            startWorkWithQRCode(qrCode: qrCode)
            
        case .failure(let error):
            errorMessage = "QR kód olvasási hiba: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func startWorkWithQRCode(qrCode: String) {
        isLoading = true
        
        Task {
            do {
                guard let workId = UUID(uuidString: qrCode) else {
                    throw NSError(domain: "Invalid QR code", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen QR kód formátum"])
                }
                
                // Munka adatainak lekérése
                let work = try await serverAuthManager.fetchWorkById(workId: workId)
                
                // Dolgozó hozzárendelése a munkához
                let success = try await serverAuthManager.assignEmployeeToWork(
                    workId: workId,
                    employeeId: userManager.currentUser?.id ?? UUID()
                )
                
                if success {
                    await MainActor.run {
                        self.activeWork = work
                        self.isWorkActive = true
                        self.isLoading = false
                        self.startTimer()
                        
                        // Sikeres indítás értesítés felhasználói adatokkal
                        let userName = userManager.currentUser?.name ?? "Ismeretlen"
                        let userEmail = userManager.currentUser?.email ?? "Ismeretlen"
                        
                        errorMessage = """
                        ✅ Munka sikeresen elindítva!
                        
                        📋 Munka adatok:
                        - Munkáltató: \(work.employerName)
                        - Pozíció: \(work.title)
                        - Fizetés: \(Int(work.wage)) Ft
                        - Fizetés típus: \(work.paymentType)
                        
                        👤 Felhasználó adatok:
                        - Név: \(userName)
                        - Email: \(userEmail)
                        - Azonosító: \(userManager.currentUser?.id.uuidString.prefix(8) ?? "Ismeretlen")
                        
                        ⏰ Munka elindítva: \(formattedCurrentDate())
                        """
                        showingError = true
                    }
                } else {
                    throw NSError(domain: "Failed to start work", code: 500, userInfo: [NSLocalizedDescriptionKey: "Nem sikerült elindítani a munkát"])
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Hiba a munka indításakor: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func startWorkWithManualCode() {
        guard !manualCodeInput.isEmpty else {
            errorMessage = "Kérjük adj meg egy érvényes kódot"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Először próbáljuk UUID-ként értelmezni (QR kód esetén)
                if let workId = UUID(uuidString: manualCodeInput) {
                    // UUID formátum - QR kódból származik
                    let work = try await serverAuthManager.fetchWorkById(workId: workId)
                    
                    let success = try await serverAuthManager.assignEmployeeToWork(
                        workId: workId,
                        employeeId: userManager.currentUser?.id ?? UUID()
                    )
                    
                    if success {
                        await handleSuccessfulWorkStart(work: work)
                    } else {
                        throw NSError(domain: "Failed to start work", code: 500, userInfo: [NSLocalizedDescriptionKey: "Nem sikerült elindítani a munkát"])
                    }
                } else {
                    // Nem UUID formátum - manuális kód
                    let work = try await serverAuthManager.fetchWorkByManualCode(manualCode: manualCodeInput)
                    
                    let success = try await serverAuthManager.assignEmployeeToWork(
                        workId: work.id,
                        employeeId: userManager.currentUser?.id ?? UUID()
                    )
                    
                    if success {
                        await handleSuccessfulWorkStart(work: work)
                    } else {
                        throw NSError(domain: "Failed to start work", code: 500, userInfo: [NSLocalizedDescriptionKey: "Nem sikerült elindítani a munkát"])
                    }
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Hiba a munka indításakor: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func handleSuccessfulWorkStart(work: WorkData) async {
        await MainActor.run {
            self.activeWork = work
            self.isWorkActive = true
            self.isLoading = false
            self.manualCodeInput = ""
            self.startTimer()
            
            // Sikeres indítás értesítés felhasználói adatokkal
            let userName = userManager.currentUser?.name ?? "Ismeretlen"
            let userEmail = userManager.currentUser?.email ?? "Ismeretlen"
            
            errorMessage = """
            ✅ Munka sikeresen elindítva!
            
            📋 Munka adatok:
            - Munkáltató: \(work.employerName)
            - Pozíció: \(work.title)
            - Fizetés: \(Int(work.wage)) Ft
            - Fizetés típus: \(work.paymentType)
            - Helyszín: \(work.location.isEmpty ? "Nincs megadva" : work.location)
            
            👤 Felhasználó adatok:
            - Név: \(userName)
            - Email: \(userEmail)
            - Azonosító: \(userManager.currentUser?.id.uuidString.prefix(8) ?? "Ismeretlen")
            
            ⏰ Munka elindítva: \(formattedCurrentDate())
            """
            showingError = true
        }
    }
    
    private func startTimer() {
        stopTimer()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func finishWork() {
        guard let work = activeWork else { return }
        
        isLoading = true
        
        Task {
            do {
                let success = try await serverAuthManager.updateWorkStatus(
                    workId: work.id,
                    status: "Befejezve",
                    employerID: work.employerID
                )
                
                if success {
                    await MainActor.run {
                        stopTimer()
                        
                        // Munka összegzés
                        let totalHours = elapsedTime / 3600
                        let totalEarnings = totalHours * Double(work.wage)
                        
                        errorMessage = """
                        ✅ Munka sikeresen befejezve!
                        
                        📊 Munka összegzés:
                        - Pozíció: \(work.title)
                        - Munkáltató: \(work.employerName)
                        - Összes idő: \(formattedTime(elapsedTime))
                        - Összes kereset: \(Int(totalEarnings)) Ft
                        - Átlagos órabér: \(Int(work.wage)) Ft/óra
                        
                        ⏰ Munka időtartama:
                        - Kezdés: \(formattedCurrentDate())
                        - Befejezés: \(formattedCurrentDate())
                        """
                        showingError = true
                        
                        isWorkActive = false
                        activeWork = nil
                        isLoading = false
                    }
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Hiba a munka befejezésekor: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "hu_HU")
        return formatter.string(from: Date())
    }
}

// MARK: - Segédelemek

struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.DesignSystem.fokekszin)
                .frame(width: 24)
            
            Text(text)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.DesignSystem.descriptions)
            
            Spacer()
        }
    }
}

struct InfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.DesignSystem.fokekszin)
            
            Text(title)
                .font(.custom("Lexend", size: 12))
                .foregroundColor(.DesignSystem.descriptions)
            
            Text(value)
                .font(.custom("Jellee", size: 16))
                .foregroundColor(.DesignSystem.fokekszin)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatusBadge: View {
    let status: String
    
    var backgroundColor: Color {
        switch status {
        case "Folyamatban":
            return .orange
        case "Befejezve":
            return .green
        case "Elutasítva":
            return .red
        default:
            return .gray
        }
    }
    
    var body: some View {
        Text(status)
            .font(.custom("Lexend", size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(8)
    }
}

#Preview {
    WorkStartEmployeeView()
}

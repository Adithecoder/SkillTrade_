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
                
                    VStack(spacing: 24) {
                        HStack {
                            Button(action: {}) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18))
                                    .foregroundColor(.DesignSystem.fokekszin)
                                    .padding(8)
                                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text("Munka indítása")
                                .font(.custom("Lexend", size: 18))
                                .foregroundColor(.DesignSystem.fokekszin)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button(action: {
                                showingQRScanner = true
                            }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.DesignSystem.fokekszin)
                                    .padding(8)
                                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        ScrollView {

                        // Header
                        VStack {
                            Text("Szkenneld be a munkáltató által biztosított QR kódot")
                                .font(.custom("Lexend", size: 16))
                                .foregroundColor(.DesignSystem.descriptions)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
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
                
                // Manuális kód bevitel - MÓDOSÍTOTT RÉSZ
                VStack(alignment: .leading, spacing: 12) {
                    Text("Manuális kód bevitel")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    TextField("Add meg a munkakódot (8 karakter vagy UUID)", text: $manualCodeInput)
                        .font(.custom("Lexend", size: 16))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: manualCodeInput) { newValue in
                            // Korlátozzuk a hosszt - max 36 karakter (UUID hossza)
                            if newValue.count > 36 {
                                manualCodeInput = String(newValue.prefix(36))
                            }
                        }
                    
                    Text("Add meg a munkáltatótól kapott 8 karakteres kódot vagy UUID-t")
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
                        .background(isValidCode(manualCodeInput) ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(!isValidCode(manualCodeInput))
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
                
                InstructionRow(icon: "1.circle", text: "Kérj QR kódot vagy írd be manuálisan a munkáltatótól")
                InstructionRow(icon: "2.circle", text: "A munka adatai betöltődnek")
                InstructionRow(icon: "3.circle", text: "Sikeres kapcsolat létrejötte után indítahatjátok a munkaidőzítőt.")
            }
            .padding(20)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // Segédfüggvény a kód érvényességének ellenőrzésére
    private func isValidCode(_ code: String) -> Bool {
        // 8 karakteres kód VAGY UUID formátum (36 karakter)
        return code.count == 8 || UUID(uuidString: code) != nil
    }
    
    // ... (activeWorkView változatlan)
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
    
    // MARK: - MÓDOSÍTOTT MŰVELETEK
    
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
            let qrCode = result.string.trimmingCharacters(in: .whitespacesAndNewlines)
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
                // 1. Próbáljuk JSON-ként értelmezni (ha a QR kód JSON objektumot tartalmaz)
                if let data = qrCode.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let workIdString = json["workId"] as? String {
                    
                    let cleanedWorkId = workIdString.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let workId = UUID(uuidString: cleanedWorkId) else {
                        throw NSError(domain: "Invalid QR code", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen munka ID a QR kódban"])
                    }
                    
                    let work = try await serverAuthManager.fetchWorkById(workId: workId)
                    await assignEmployeeToWork(workId: workId, work: work)
                    
                }
                // 2. Próbáljuk tiszta UUID-ként (36 karakteres formátum)
                else if let workId = UUID(uuidString: qrCode) {
                    let work = try await serverAuthManager.fetchWorkById(workId: workId)
                    await assignEmployeeToWork(workId: workId, work: work)
                }
                // 3. Egyéb eset - hiba
                else {
                    throw NSError(
                        domain: "Invalid QR code",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Érvénytelen QR kód formátum. A kód nem tartalmaz érvényes UUID-t."]
                    )
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
    
    private func assignEmployeeToWork(workId: UUID, work: WorkData) async {
        do {
            let success = try await serverAuthManager.assignEmployeeToWork(
                workId: workId,
                employeeId: userManager.currentUser?.id ?? UUID()
            )
            
            if success {
                await handleSuccessfulWorkStart(work: work)
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
    
    private func startWorkWithManualCode() {
        let cleanedCode = manualCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedCode.isEmpty else {
            errorMessage = "Kérjük adj meg egy érvényes kódot"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // 1. Próbáljuk UUID-ként (36 karakteres formátum)
                if let workId = UUID(uuidString: cleanedCode) {
                    let work = try await serverAuthManager.fetchWorkById(workId: workId)
                    await assignEmployeeToWork(workId: workId, work: work)
                }
                // 2. Próbáljuk rövid kódként (8 karakter)
                else if cleanedCode.count == 8 {
                    let work = try await serverAuthManager.fetchWorkByManualCode(manualCode: cleanedCode)
                    await assignEmployeeToWork(workId: work.id, work: work)
                }
                // 3. Egyéb eset - hiba
                else {
                    throw NSError(
                        domain: "Invalid code format",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Érvénytelen kód formátum. Használj 8 karakteres kódot vagy UUID-t (36 karakter)."]
                    )
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
            
            // Sikeres indítás értesítés
            let userName = userManager.currentUser?.name ?? "Ismeretlen"
            
            errorMessage = """
            ✅ Munka sikeresen elindítva!
            
            📋 Munka adatok:
            - Munkáltató: \(work.employerName)
            - Pozíció: \(work.title)
            - Fizetés: \(Int(work.wage)) Ft
            - Fizetés típus: \(work.paymentType)
            - Helyszín: \(work.location.isEmpty ? "Nincs megadva" : work.location)
            
            👤 Dolgozó:
            - Név: \(userName)
            
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

// ... (a segéd struktúrák változatlanok maradnak)

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

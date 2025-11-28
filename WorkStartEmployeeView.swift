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
    @State private var isWorkPaused = false
    @State private var isWorkStarted = false
    @State private var totalPausedTime: TimeInterval = 0
    @State private var pauseStartTime: Date? = nil
    
    @State private var showingCompletionDialog = false
        @State private var completionCode = ""
        @State private var enteredCompletionCode = ""
        @State private var isVerifyingCompletion = false

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
                        .disabled(isWorkActive)

                    }
                    .padding(.horizontal)
                    ScrollView {

                        
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
            // A body View-ben add hozzá a .sheet modifier-t a meglévő sheet-ek mellé:
            .sheet(isPresented: $showingCompletionDialog) {
                WorkCompletionDialog(
                    work: activeWork ?? WorkData.mockWork,
                    completionCode: completionCode,
                    enteredCode: $enteredCompletionCode,
                    isVerifying: $isVerifyingCompletion,
                    onComplete: completeWorkWithCode,
                    onCancel: {
                        showingCompletionDialog = false
                        enteredCompletionCode = ""
                    }
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
                Button(action: {
                    showingQRScanner = true
                }) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 60))
                        .foregroundColor(.DesignSystem.fokekszin)
                }
                Text("Nincs aktív munka")
                    .font(.custom("Jellee", size: 22))
                    .foregroundColor(.DesignSystem.fokekszin)
                
                Button(action: {
                    showingQRScanner = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("QR Kód Szkennelése")
                            .font(.custom("Lexend", size: 20))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.DesignSystem.fokekszin)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LinearGradient(
                                gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 3)
                        )
                    .cornerRadius(20)
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
                    Text("Manuális kód bevitele")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    TextField("Add meg a munkakódot", text: $manualCodeInput)
                        .font(.custom("Lexend", size: 16))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(15)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(LinearGradient(
                                    gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.fenyozold.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 3)
                            )
                        .onChange(of: manualCodeInput) { newValue in
                            // Korlátozzuk a hosszt - max 36 karakter (UUID hossza)
                            if newValue.count > 36 {
                                manualCodeInput = String(newValue.prefix(36))
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
                                .font(.custom("Lexend", size: 16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isValidCode(manualCodeInput) ? Color.DesignSystem.fokekszin : Color.gray)
                        .cornerRadius(15)
                    }
                    .disabled(!isValidCode(manualCodeInput))
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                )

            
            Text("Útmutató")
                .font(.custom("Jellee", size: 22))
                .foregroundColor(.DesignSystem.fokekszin)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, -20)
            // Utasítások
            VStack(alignment: .leading, spacing: 16) {


                
                InstructionRow(icon: "1.circle", text: "Kérj QR kódot a munkáltatótól vagy írd be manuálisan")
                InstructionRow(icon: "2.circle", text: "A munka adatai betöltődnek")
                InstructionRow(icon: "3.circle", text: "Sikeres kapcsolat létrejötte után indítahatjátok a munkaidőzítőt.")
            }
            .padding(20)
            .background(Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                )
            .cornerRadius(20)
        }
    }
    
    private func startWorkTimer() {
        isWorkStarted = true
        isWorkPaused = false
//        startTimer()
        
//        errorMessage = "✅ Munka időzítő elindítva!"
//        showingError = true
    }
    
    private func togglePause() {
        if isWorkPaused {
            // Folytatás
            if let pauseStart = pauseStartTime {
                totalPausedTime += Date().timeIntervalSince(pauseStart)
                pauseStartTime = nil
            }
            isWorkPaused = false
            startTimer()
        } else {
            // Szünet
            isWorkPaused = true
            pauseStartTime = Date()
            stopTimer()
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
                
                // Időzítő Eltelt idő
                VStack(spacing: 12) {

                    Text(formattedTime(isWorkStarted ? elapsedTime : 0)) // CSAK AKKOR MUTASD AZ IDŐT HA ELINDULT
                        .font(.custom("Lexend", size: 38))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .monospacedDigit()
                }
                
                Divider()
                
                // Munka részletek
                HStack(spacing: 20) {
                    InfoItem(icon: "dollarsign.circle", title: "Fizetés", value: "\(Int(work.wage)) Ft")
                    InfoItem(icon: "creditcard", title: "Fizetés típus", value: work.paymentType)
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
                if !isWorkStarted {
                    Button(action: {
                        startWorkTimer()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                            Text("Munka Indítása")
                                .font(.custom("Jellee", size: 18))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                } else {
                    HStack(spacing: 12) {
                        Button(action: {
                            togglePause()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: isWorkPaused ? "play.circle.fill" : "pause.circle.fill")
                                Text(isWorkPaused ? "Folytatás" : "Szünet")
                                    .font(.custom("Jellee", size: 16))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isWorkPaused ? Color.green : Color.orange)
                            .cornerRadius(12)
                        }
                        
                        // A meglévő befejezés gomb maradjon így:
                        Button(action: {
                            finishWork() // Ez most már a lezárási dialógust nyitja meg
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.circle.fill")
                                Text("Befejezés")
                                    .font(.custom("Jellee", size: 16))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                }
                Text("Csatlakozva: \(formattedCurrentDate())")
                    .font(.custom("Lexend", size: 14))

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
                        userInfo: [NSLocalizedDescriptionKey: "Érvénytelen QR kód formátum. A kód nem tartalmaz érvényes azonosítót."]
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
                        userInfo: [NSLocalizedDescriptionKey: "Érvénytelen kódformátum. Használj 8 karakteres kódot vagy UUID-t (36 karakter)."]
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
                // CSAK a lezárási kód lekérése
                let code = try await serverAuthManager.getCompletionCode(workId: work.id)
                
                await MainActor.run {
                    self.completionCode = code
                    self.showingCompletionDialog = true
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Hiba a lezárási kód lekérésekor: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func completeWorkWithCode() {
        guard let work = activeWork else { return }

        // Ellenőrizzük a kódot
        guard enteredCompletionCode == completionCode else {
            errorMessage = "❌ Hibás lezárási kód! Kérjük ellenőrizd a megadott kódot."
            showingError = true
            isVerifyingCompletion = false
            return
        }

        isVerifyingCompletion = true

        Task {
            do {
                let success = try await serverAuthManager.completeWorkAsEmployee(
                    workId: work.id,
                    employeeId: userManager.currentUser?.id ?? UUID()
                )

                if success {
                    await MainActor.run {
                        stopTimer()
                        
                        let totalWorkTime = elapsedTime - totalPausedTime
                        let totalHours = totalWorkTime / 3600
                        let totalEarnings = totalHours * Double(work.wage)
                        
                        // Sikeres nézet megjelenítése
                        let successView = WorkCompletionSuccessView(
                            completedWork: work,
                            totalEarnings: totalEarnings,
                            totalWorkTime: totalWorkTime
                        )
                        
                        // Navigáció a sikeres nézetre
                        // Ehhez szükséges a navigációs kontroller beállítása
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController = UIHostingController(rootView: successView)
                        }
                        
                        // Lezárási dialógus bezárása
                        showingCompletionDialog = false
                        isVerifyingCompletion = false
                    }
                } else {
                    await MainActor.run {
                        isVerifyingCompletion = false
                        errorMessage = "❌ Hiba a munka befejezésekor: A szerver nem tudta feldolgozni a kérést"
                        showingError = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    isVerifyingCompletion = false
                    errorMessage = "❌ Hiba a munka befejezésekor: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    private func resetWorkState() {
        isWorkActive = false
        isWorkStarted = false
        isWorkPaused = false
        activeWork = nil
        elapsedTime = 0
        totalPausedTime = 0
        pauseStartTime = nil
        isLoading = false
        
        // Opcionális: automatikus visszatérés az inaktív nézetbe
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showingError = false
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

// MARK: - Work Completion Dialog
struct WorkCompletionDialog: View {
    let work: WorkData
    let completionCode: String
    @Binding var enteredCode: String
    @Binding var isVerifying: Bool
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showCopiedMessage = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Fejléc
                HStack {
                    Button(action: {
                        onCancel()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Munka lezárása")
                        .font(.custom("Lexend", size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    Button(action: {
                        onComplete()
                    }) {
                        Image(systemName: "lock")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.DesignSystem.fokekszin)
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }

                }
                .padding(.horizontal)
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    Text("Munka lezárása")
                        .font(.custom("Jellee", size: 24))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    Text("Kérj lezárási kódot a munkáltatótól")
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                

                
                // Munka információk
                VStack(alignment: .leading, spacing: 12) {
                    Text("Munka adatai:")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(work.title)
                                .font(.custom("Jellee", size: 18))
                                .foregroundColor(.primary)
                            
                            Text(work.employerName)
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(work.wage)) Ft")
                            .font(.custom("Jellee", size: 16))
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                // Kód bevitel
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Lezárási kód:")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if showCopiedMessage {
                            Text("✓ Kimásolva")
                                .font(.custom("Lexend", size: 12))
                                .foregroundColor(.green)
                        }
                    }
                    
                    TextField("Add meg a 6 számjegyű kódot", text: $enteredCode)
                        .font(.custom("Lexend", size: 20))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .onChange(of: enteredCode) { newValue in
                            // Csak számok és max 6 karakter
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            enteredCode = String(filtered.prefix(6))
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                        )
                    
                    Text("Kérj 6 számjegyű kódot a munkáltatótól")
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(.gray)
                    
                    
                    Text("A munka lezárásával jogosulttá válsz fizetésed számlázásához.")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.gray)
                    

                }
                Text("Köszönjük, hogy a SkillTrade-et választottad!")
                    .font(.custom("Jellee", size: 16))
                
                // Művelet gombok
                VStack(spacing: 12) {
                    Button(action: {
                        onComplete()
                    }) {
                        HStack {
                            if isVerifying {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Munka lezárása")
                                .font(.custom("Lexend", size: 20))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(enteredCode.count == 6 ? Color.green : Color.gray)
                        .cornerRadius(20)
                    }
                    .disabled(enteredCode.count != 6 || isVerifying)

                }
            }
            .padding()

        }
    }
}

// MARK: - Work Completion Success View
struct WorkCompletionSuccessView: View {
    let completedWork: WorkData
    let totalEarnings: Double
    let totalWorkTime: TimeInterval
    @Environment(\.dismiss) var dismiss
    @State private var animationProgress: Double = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .padding(8)
                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                    .clipShape(Circle())
            }
            
            
            Spacer()


            Button(action: {
            }) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 18))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .padding(8)
                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        ZStack {

            
            VStack(spacing: 30) {
                Spacer()
                
                // Animált pipa
                ZStack {
                    Circle()
                        .stroke(Color.DesignSystem.fenyozold.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: animationProgress)
                        .stroke(Color.DesignSystem.fenyozold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.DesignSystem.fenyozold)
                        .scaleEffect(checkmarkOpacity)
                }
                
                // Animált szöveg
                VStack(spacing: 20) {

                    Text("Munka sikeresen befejezve!")
                        .font(.custom("Jellee", size: 24))
                        .foregroundColor(.DesignSystem.fokekszin)
                    Text("Gratulálunk a munka elvégzéséhez!")
                        .font(.custom("Lexend", size: 18))
                        .foregroundColor(.DesignSystem.descriptions)
                }
                
                .multilineTextAlignment(.center)

                
                Spacer()
                
                // Gombok
                VStack(spacing: 12) {
                    Button(action: {
                        // Navigáció a teljesítések nézetre
                        showCompletedWorksView()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.clipboard")
                            Text("Teljesítések megtekintése")
                                .font(.custom("Lexend", size: 18))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.DesignSystem.fokekszin)
                        .cornerRadius(12)
                    }
                    .opacity(buttonOpacity)

                }
            }
            .padding(30)
        }
        .onAppear {
            startAnimations()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func startAnimations() {
        // Kör animáció
        withAnimation(.easeInOut(duration: 1.5)) {
            animationProgress = 1.0
        }
        
        // Pipka animáció
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                checkmarkOpacity = 1.0
            }
        }
        
        // Szöveg animáció
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.8)) {
                textOpacity = 1.0
            }
        }
        
        // Gomb animáció
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.8)) {
                buttonOpacity = 1.0
            }
        }
    }
    
    private func showCompletedWorksView() {
        // Implementáld a navigációt a teljesítések nézetre
        // Példa: navigationController?.pushViewController...
        print("Navigálás a teljesítések nézetre")
    }
    
    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Animated Text Component
struct AnimatedText: View {
    let text: String
    let speed: Double
    let opacity: Double
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    var body: some View {
        Text(displayedText)
            .opacity(opacity)
            .onChange(of: opacity) { newValue in
                if newValue > 0 && displayedText.isEmpty {
                    startTypingAnimation()
                }
            }
    }
    
    private func startTypingAnimation() {
        displayedText = ""
        currentIndex = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText += String(text[index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
        timer.fire()
    }
}

// MARK: - Completion Info Row
struct CompletionInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.DesignSystem.fokekszin)
                    .frame(width: 24)
                
                Text(title)
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(.DesignSystem.descriptions)
            }
            
            Spacer()
            
            Text(value)
                .font(.custom("Jellee", size: 16))
                .foregroundColor(.DesignSystem.fokekszin)
        }
    }
}

// MARK: - Completed Works History View
struct CompletedWorksView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var serverAuthManager = ServerAuthManager.shared
    @State private var completedWorks: [WorkData] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.DesignSystem.fokekszin)
                } else if completedWorks.isEmpty {
                    EmptyStateView2()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(completedWorks, id: \.id) { work in
                                CompletedWorkCard(work: work)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Teljesített munkák")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadCompletedWorks()
            }
        }
    }
    
    private func loadCompletedWorks() {
        guard let employeeId = userManager.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                // Itt implementáld a befejezett munkák lekérését
                // Ez egy példa implementáció
                let allWorks = try await serverAuthManager.fetchWorks()
                let completed = allWorks.filter { work in
                    work.statusText == "Befejezve" && work.employeeID == employeeId
                }
                
                await MainActor.run {
                    self.completedWorks = completed.sorted { $0.createdAt > $1.createdAt }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Hiba a munkák betöltésekor: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Completed Work Card
struct CompletedWorkCard: View {
    let work: WorkData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(work.title)
                        .font(.custom("Jellee", size: 20))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    Text(work.employerName)
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.DesignSystem.descriptions)
                }
                
                Spacer()
                
                Text("Befejezve")
                    .font(.custom("Lexend", size: 12))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                InfoItem(icon: "dollarsign.circle", title: "Fizetés", value: "\(Int(work.wage)) Ft")
                InfoItem(icon: "clock", title: "Időtartam", value: formattedDuration)
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
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var formattedDuration: String {
        // Implementáld az időtartam formázását a tényleges adatok alapján
        return "8:00"
    }
}

// MARK: - Empty State View
struct EmptyStateView2: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.DesignSystem.fokekszin.opacity(0.5))
            
            Text("Még nincsenek teljesített munkáid")
                .font(.custom("Jellee", size: 22))
                .foregroundColor(.DesignSystem.fokekszin)
                .multilineTextAlignment(.center)
            
            Text("Az itt elvégzett munkáid jelennek meg a jövőben")
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.DesignSystem.descriptions)
                .multilineTextAlignment(.center)
        }
        .padding()
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
                .foregroundColor(.black)
            
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

#Preview("WorkCompletionDialog") {
    @Previewable @State var entered = ""
    @Previewable @State var verifying = false

    WorkCompletionDialog(
        work: WorkData.mockWork,
        completionCode: "123456",
        enteredCode: $entered,
        isVerifying: $verifying,
        onComplete: {
            verifying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                verifying = false
            }
        },
        onCancel: {
            entered = ""
            verifying = false
        }
    )
}



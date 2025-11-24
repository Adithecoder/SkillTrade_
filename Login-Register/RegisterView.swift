    import SwiftUI
    import DesignSystem
    import Combine
    // MARK: - Register View Model
    class RegisterViewModel: ObservableObject {
        @Published var name = ""
        @Published var username = ""
        @Published var email = ""
        @Published var password = ""
        @Published var confirmPassword = ""
        @Published var isLoading = false
        @Published var error: String? = nil
        @Published var isRegistered = false
        @Published var acceptedTerms = false
        @Published var acceptedAge = false
        @Published var age = "" // Új életkor mező
        
        private let userManager = UserManager.shared
        
        var isValid: Bool {
            !name.isEmpty &&
            !username.isEmpty &&
            !email.isEmpty &&
            !password.isEmpty &&
            password == confirmPassword &&
            acceptedTerms &&
            acceptedAge &&
            !age.isEmpty && // Életkor ellenőrzése
            Int(age) != nil // Ellenőrizzük, hogy szám-e
        }
        
        func register() {
                isLoading = true
                
                guard isValid else {
                    error = "Kérünk, töltsd ki az összes mezőt helyesen"
                    isLoading = false
                    return
                }
                
                guard let ageInt = Int(age) else {
                    error = "Érvényes életkort adj meg"
                    isLoading = false
                    return
                }
                
                guard ageInt >= 18 else {
                    error = "A regisztrációhoz legalább 18 évesnek kell lenned"
                    isLoading = false
                    return
                }
                
                // Lokális regisztráció (eredeti)
                userManager.register(name: name, email: email, username: username, password: password)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isRegistered = true
                    self.isLoading = false
                }
            }
        }

    // MARK: - Register View
struct RegisterView: View {
    @StateObject private var viewModel = RegisterViewModel()
    @StateObject private var serverAuth = ServerAuthManager.shared
    @State private var showLogin = false
    @Environment(\.dismiss) var dismiss
    @State private var showTerms = false
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                HStack {
                    Button(action: {
                        dismiss()

                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18))
                            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                                            startPoint: .leading,
                                                            endPoint: .trailing))
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Regisztráció")
                        .font(.custom("Lexend", size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                    }) {
                        Image(systemName: "person.crop.circle.fill.badge.plus")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.DesignSystem.fokekszin)
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                VStack(spacing: 20) {
                    
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .resizable()
                        .frame(width: 120, height: 100)
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                                        startPoint: .top,
                                                        endPoint: .trailing))
                        .symbolEffect(.bounce, value: viewModel.isLoading)
                        .shadow(color: .DesignSystem.descriptions.opacity(0.3), radius: 16, x: 4, y: 4)
                    
                    Text("Üdvözlünk a SkillTrade-nél!")
                        .font(.custom("Jellee", size: 26))
                        .multilineTextAlignment(.center)
                    
                    
                    Text("Regisztrálj!")
                        .font(.custom("Jellee", size: 36))
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing))
                        .multilineTextAlignment(.center)

                    
                    VStack(spacing: 20) {
                        // Name and Age fields
                        HStack{
                            TextField("Teljes név", text: $viewModel.name)
                                .foregroundStyle(.white)
                                .padding(-5)
                                .textFieldStyle(ModernTextFieldStyle())
                                .font(.custom("Jellee", size: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                                .cornerRadius(15)
                            
                            // Életkor mező - szám billentyűzettel
                            TextField("Életkor", text: $viewModel.age)
                                .keyboardType(.numberPad)
                                .foregroundStyle(.white)
                                .padding(-5)
                                .textFieldStyle(ModernTextFieldStyle())
                                .font(.custom("Jellee", size: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                                .cornerRadius(15)
                        }
                        
                        TextField("Felhasználónév", text: $viewModel.username)
                            .foregroundStyle(.white)
                            .padding(-5)
                            .textFieldStyle(ModernTextFieldStyle())
                            .font(.custom("Jellee", size: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(15)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        
                        // Email field
                        TextField("E-mail cím", text: $viewModel.email)
                            .foregroundStyle(.white)
                            .padding(-5)
                            .textFieldStyle(ModernTextFieldStyle())
                            .font(.custom("Jellee", size: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(15)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled(true)
                        
                        // Password fields
                        SecureField("Jelszó", text: $viewModel.password)
                            .foregroundStyle(.white)
                            .padding(-5)
                            .textFieldStyle(ModernTextFieldStyle())
                            .font(.custom("Jellee", size: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(15)
                        SecureField("Jelszó validáció", text: $viewModel.confirmPassword)
                            .foregroundStyle(.white)
                            .padding(-5)
                            .textFieldStyle(ModernTextFieldStyle())
                            .font(.custom("Jellee", size: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(15)
                        
                        // Terms checkboxes
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "18.circle")
                                    .font(.title2)
                                    .foregroundStyle(Color.DesignSystem.bordosszin)
                                Text("Kijelentem, hogy elmúltam legalább 18 éves.")
                                    .font(.custom("Lexend", size: 11))
                                    .foregroundColor(.DesignSystem.bordosszin)
                                    .padding(.horizontal, 10)
                                
                                Spacer()
                                
                                Toggle("", isOn: $viewModel.acceptedAge)
                                    .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.bordosszin))
                                    .labelsHidden()
                                    .frame(width: 30)
                            }
                            Button(action: { showTerms = true }) {

                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "book.pages")
                                    .font(.title2)
                                    .foregroundStyle(Color.DesignSystem.descriptions)
                                    Text("Elfogadom a felhasználási feltételeket és az adatvédelmi irányelveket.")
                                        .font(.custom("Lexend", size: 11))
                                        .foregroundStyle(Color.DesignSystem.descriptions)
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, 10)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $viewModel.acceptedTerms)
                                        .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
                                        .labelsHidden()
                                        .frame(width: 30)
                                }
                            }
//                            NavigationLink(destination: LoginView()) {
//                                Text("Tagunk vagy már? Jelentkezz be!")
//                                    .font(.custom("Jellee", size: 20))
//                                    .foregroundColor(Color.DesignSystem//.fokekszin)
//                                    .multilineTextAlignment(.center)
//
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Tagunk vagy már? Jelentkezz be!")
                                    .font(.custom("Jellee", size: 20))
                                    .foregroundColor(Color.DesignSystem.fokekszin)
                                    .multilineTextAlignment(.center)
                            }
 //                       }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom,20)
                        
                        // Error message
                        if let error = viewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.custom("Lexend", size: 14))
                        }
                        
                        // Register button
                        Button(action: register) {
                            if viewModel.isLoading || serverAuth.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Regisztráció")
                                    .font(.custom("Lexend", size: 20))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin.opacity(0.8), .DesignSystem.descriptions.opacity(0.8)]),
                                                   startPoint: .leading,
                                                   endPoint: .trailing))
                        .cornerRadius(20)
                        .disabled(!viewModel.isValid || viewModel.isLoading)
                        .shadow(color: Color.DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 2))
                    }
                    .padding(.horizontal)
                }
            }

        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showTerms) {
            TermsView()
        }
        .alert("Sikeres regisztráció", isPresented: $viewModel.isRegistered) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Kérlek jelentkezz be a folytatáshoz!")
        }
        .alert("Szerver hiba", isPresented: .init(
            get: { serverAuth.error != nil },
            set: { if !$0 { serverAuth.error = nil } }
        )) {
            Button("OK") { serverAuth.error = nil }
        } message: {
            Text(serverAuth.error ?? "Ismeretlen hiba")
        }
        .alert("Sikeres regisztráció", isPresented: .init(
            get: { viewModel.isRegistered || serverAuth.isAuthenticated },
            set: { _ in }
        )) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Kérlek jelentkezz be a folytatáshoz!")
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Registration Error"),
                message: Text(UserManager.shared.error?.localizedDescription ?? "Unknown error")
            )
        }
        .interactiveDismissDisabled(viewModel.isLoading)
    }
    
    private func register() {
        guard let ageInt = Int(viewModel.age) else { return }
        
        // Először próbáljuk a szerveres regisztrációt
        serverAuth.register(
            name: viewModel.name,
            email: viewModel.email,
            username: viewModel.username,
            password: viewModel.password,
            age: ageInt
        ) { success in
            if success {
                // Szerveres regisztráció sikeres
                DispatchQueue.main.async {
                    viewModel.isRegistered = true
                }
            } else {
                // Ha a szerveres regisztráció nem sikerül, akkor lokális
                viewModel.register()
            }
        }
    }
}

    // MARK: - Terms View

struct TermsView: View {
    @Environment(\.dismiss) var dismiss
    
    // A szakaszok címei – ezekből lesznek a gombok és a cél ID-k
    let rules = ["Általános", "Adatvédelem", "Korhatárszabályok"]
    
    var body: some View {
        NavigationStack {
            
            HStack {
                Button(action: {
                    dismiss()

                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Felhasználási feltételek")
                    .font(.custom("Lexend", size: 18))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                }) {
                    Image(systemName: "book")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.DesignSystem.fokekszin)
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Egyetlen ScrollViewReader, hogy a gombok közvetlenül tudjanak görgetni
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 16) {
                    Text("Felhasználási feltételeink")
                        .font(.custom("Jellee", size: 25))
                        .bold()
                    
                    Text("Az alkalmazás használatával elfogadod az alábbi feltételeket.")
                        .font(.custom("Jellee", size: 14))
                        .foregroundStyle(.red)
                    
                    // Tartalomjegyzék: gombok a rules tömbből
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            
                            Text("Tartalom:")
                                .font(.custom("Jellee", size: 14))
                                .foregroundStyle(Color.DesignSystem.fokekszin)

                            ForEach(rules, id: \.self) { title in
                                Button {
                                    withAnimation {
                                        proxy.scrollTo(title, anchor: .top)
                                    }
                                } label: {
                                    Text(title)
                                        .foregroundStyle(Color.DesignSystem.fokekszin)
                                        .font(.custom("Jellee", size: 14))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 10)
                                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                        .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.DesignSystem.fenyozold, lineWidth: 3)
                                        )
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    // Tartalom: azonosítók a címeken, hogy oda lehessen görgetni
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // 1. szakasz
                            Text("1. Általános rendelkezések")
                                .font(.custom("Jellee", size: 16))
                                .id("Általános")
                            Text("A jelen Szabályzatban nem szabályozott kérdésekre, valamint jelen Szabályzat értelmezésére a magyar jog az irányadó, különös tekintettel a Polgári Törvénykönyvről szóló 2013. évi V. törvény („Ptk.”) és az elektronikus kereskedelmi szolgáltatások, valamint az információs társadalommal összefüggő szolgáltatások egyes kérdéseiről szóló 2001. évi CVIII. törvény vonatkozó rendelkezéseire. A vonatkozó jogszabályok kötelező rendelkezései a felekre külön kikötés nélkül is irányadók.")
                            Text("Hatály az Általános Szerződési Feltételek (ÁSZF) módosítása")
                            

                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.DesignSystem.descriptions)
                            
                            // 2. szakasz
                            Text("2. Adatvédelem")
                                .font(.custom("Jellee", size: 16))
                                .id("Adatvédelem")
                            Text("A Szolgáltató adatkezelésére a személyes adatok védelméről és a közérdekű adatok nyilvánosságáról szóló 1992. évi LXIII. törvény (Avtv.) irányadó. Az adatszolgáltatás önkéntes.")
                            Text("Az adatkezelés célja a megbízási szerződésben foglalt, Adatkezelő által vállalt szolgáltatások és kötelezettségek teljesítése, jogok érvényesítése, az ügyfél, azonosítása, az Ügyféllel való kapcsolattartás és kommunikáció.")
                            Text("További személyes adatok kezelése törvényi felhatalmazáson alapulhat, amelynek célja jogszabályi kötelezettségek teljesítése. Kezelt adatok: adószám, adóazonosító jel, TAJ szám, bankszámlaszám stb.")

                            
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.DesignSystem.descriptions)
                            
                            // 2. szakasz
                            Text("3. Korhatárszabályok")
                                .font(.custom("Jellee", size: 16))
                                .id("Korhatárszabályok")
                            Text("A SkillTrade szolgáltatásainak használatához a minimum életkor 18 év. Munkavállalóink felelősséget vállalnak saját magukért.")
                            


                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.DesignSystem.descriptions)
                        }
                        .padding(.bottom, 2)
                        .font(.custom("Lexend", size: 16))
                        .padding()
                    }
                }
                .padding()
            }
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("Bezárás") { dismiss() }
//                        .font(.custom("Lexend", size: 17))
//                        .foregroundStyle(
//                            LinearGradient(
//                                colors: [.red, .blue],
//                                startPoint: .leading,
//                                endPoint: .trailing
//                            )
//                        )
//                }
//            }
        }
    }
}

    // MARK: - Preview Provider
    struct RegisterView_Previews: PreviewProvider {
        static var previews: some View {
            RegisterView()
            TermsView()
        }
    }

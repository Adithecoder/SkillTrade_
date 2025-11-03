import SwiftUI
import DesignSystem

struct ServiceDetailView: View {
    let service: Service
    @State private var showAppointment = false
    @State private var showChat = false
    @State private var isSaved = false
    @ObservedObject private var userManager = UserManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                serviceImage
                serviceDetailsCard
                actionButtons
                moreinfosaboutjob
            }
        }
        .navigationBarTitle(service.advertiser.name, displayMode: .inline)
        .sheet(isPresented: $showAppointment) {
            AppointmentView(service: service)
        }
//        .sheet(isPresented: $showChat) {
//            ChatView(user: service.advertiser)
//        }
        .onAppear {
            checkSavedStatus()
        }
    }
    
    // MARK: - Subviews
    
    private var serviceImage: some View {
        Group {
            if let firstMediaURL = service.mediaURLs.first {
                AsyncImage(url: firstMediaURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                }
            }
        }
    }
    
    private var serviceDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            advertiserSection
            workDetailsSection
            paymentSection
        }
        .padding()
        .background(Color.DesignSystem.fokekszin.opacity(0.3))
        .cornerRadius(30)
        .shadow(color: Color(#colorLiteral(red: 0.1490196078, green: 0.3921568627, blue: 0.5568627451, alpha: 1)), radius: 16, x: 4, y: 4)
        .padding(.horizontal)
    }
    
    private var advertiserSection: some View {
        VStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.DesignSystem.fokekszin.opacity(0.3))
                .frame(height: 110)
            
            HStack {
                NavigationLink(destination: UserDetailView(user: service.advertiser)) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.black)
                    
                    Text(service.advertiser.name)
                        .foregroundColor(.black)
                        .font(.custom("OrelegaOne-Regular", size: 20))
                    
                    if service.advertiser.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.DesignSystem.descriptions)
                            .font(.subheadline)
                    }
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.DesignSystem.descriptions)
                        .frame(width: 70, height: 30)
                        .overlay(
                            Text("Követés")
                                .font(.custom("OrelegaOne-Regular", size: 16))
                                .foregroundColor(.black)
                        )
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.DesignSystem.descriptions)
                        .frame(width: 70, height: 30)
                        .overlay(
                            Text("Mentés")
                                .font(.custom("OrelegaOne-Regular", size: 16))
                                .foregroundColor(.black)
                        )
                }
            }
            .padding(.bottom, 10)
            .underlineTextField()
            .padding(.top, -110)
            
            ratingSection
        }
    }
    
    private var ratingSection: some View {
        HStack {
            ForEach(0..<5) { index in
                Image(systemName: index < Int(service.rating) ? "star.fill" : "star")
                    .foregroundColor(.DesignSystem.fokekszin)
            }
            Text("\(service.reviewCount) értékelés")
                .font(.custom("OrelegaOne-Regular", size: 16))
                .foregroundColor(.black)
        }
        .padding(2)
        .underlineTextField()
        .padding(.top, -70)
    }
    
    private var workDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A munka részletei")
                .font(.custom("OrelegaOne-Regular", size: 20))
                .padding(.top)
            
            divider
            
            skillsScrollView
            
            divider
            
            Text(service.description)
                .font(.custom("OrelegaOne-Regular", size: 20))
                .padding(.top, -10)
            
            divider
        }
    }
    
    private var skillsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(service.skills, id: \.self) { skill in
                    Text(skill)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .font(.custom("OrelegaOne-Regular", size: 16))
                        .background(Color.DesignSystem.fokekszin.opacity(0.3))
                        .foregroundColor(.DesignSystem.descriptions)
                        .cornerRadius(20)
                }
            }
        }
        .padding(.top, -10)
    }
    
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fizetési árajánlat")
                    .font(.custom("OrelegaOne-Regular", size: 20))
                    .padding(.top, -10)
                Spacer()
                Text("\(Int(service.price)) Ft")
                    .font(.custom("OrelegaOne-Regular", size: 20))
                    .foregroundColor(.yellow)
                    .padding(.top, -10)
            }
            
            
            HStack {
                
                Text("Fizetési mód")
                    .font(.custom("OrelegaOne-Regular", size: 20))
                    .padding(.top, -10)
                
                Spacer()
                
                Text(service.fizetesimod.rawValue)
                    .foregroundColor(.yellow)
                    .font(.custom("OrelegaOne-Regular", size: 20))
                    .padding(.top, -10)
            }
            
            divider
        }
    }
    
    private var divider: some View {
        Rectangle()
            .frame(height: 3)
            .foregroundColor(.DesignSystem.descriptions)
            .padding(.top, -10)
    }
    
    private var actionButtons: some View {
        HStack {
            Button(action: { showAppointment.toggle() }) {
                Text("Munkanap foglalása")
                    .font(.custom("OrelegaOne-Regular", size: 20))
                    .foregroundColor(.yellow)
            }
            .frame(width: 230, height: 40)
            .background(Color.DesignSystem.fokekszin)
            .cornerRadius(15)
            .shadow(color: .DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
            
            Button(action: toggleSaveService) {
                Image(isSaved ? "heartfill" : "heart")
                    .padding(8)
                    .background(Color(#colorLiteral(red: 0.1490196078, green: 0.3921568627, blue: 0.5568627451, alpha: 1)).opacity(0.6))
                    .cornerRadius(15)
                    .shadow(color: Color(#colorLiteral(red: 0.1490196078, green: 0.3921568627, blue: 0.5568627451, alpha: 1)), radius: 16, x: 4, y: 4)
            }
            
            Button(action: { showChat.toggle() }) {
                Image("message")
                    .padding(6)
                    .background(Color(#colorLiteral(red: 0.1490196078, green: 0.3921568627, blue: 0.5568627451, alpha: 1)).opacity(0.6))
                    .cornerRadius(15)
                    .shadow(color: Color(#colorLiteral(red: 0.1490196078, green: 0.3921568627, blue: 0.5568627451, alpha: 1)), radius: 16, x: 4, y: 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.DesignSystem.fokekszin.opacity(0.3))
                .frame(width: 360, height: 60)
                .shadow(color: Color(#colorLiteral(red: 0.1490196078, green: 0.3921568627, blue: 0.5568627451, alpha: 1)), radius: 16, x: 4, y: 4)
        )
            
       
    }
    
    private var moreinfosaboutjob: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("További információk a munkanap foglalásáról")
                .foregroundColor(.black)
                .underlineTextField()
                .font(.custom("OrelegaOne-Regular", size: 18))

            VStack{
                    
                Text("A munkavégzés teljes terültén saját felelősségedre vállalod a munkát. Baleset esetén a munkavégzés helyszínén a SkillTrade alkalmazásunkban tudsz segítséget kérni, valamint az ezzel járó költségeket (ha az ellátás sügős lenne) a SkillTrade fedezi. Fontos, hogy a munkavégzés során mindig tartsd be a biztonsági előírásokat és szabályokat.")
                    .padding(10)
                    .font(.custom("OrelegaOne-Regular", size: 16))
                    .foregroundColor(.black)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.DesignSystem.descriptions)
                            .blur(radius: 4)
                    )
                    .padding(10)
                    .padding(.bottom, -15)
                
                        
                
                Text("A munkavégzés során minden szükséges eszközt és anyagot a munkaadó biztosít, kivéve ha másképp állapodtok meg. Ezeket az eszközöket és anyagokat a munkavégzés előtt át kell adnia számodra, de az átvételtől kezdve te vagy felelős értük. A munkavégzés során keletkezett károkért is te vagy felelős, kivéve ha bizonyítani tudod, hogy a károkozás nem a te hibádból ered.")
                    .padding(10)
                    .font(.custom("OrelegaOne-Regular", size: 16))
                    .foregroundColor(.black)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.DesignSystem.descriptions)
                            .blur(radius: 4)
                    )
                    .padding(10)
                    .padding(.bottom, -15)

                
                Text("A munkádért járó kifizetésedet a SkillTrade alkalmazásban fogod megkapni, a munkavégzés befejezése után. A kifizetés általában 24 órán belül megtörténik, de előfordulhat, hogy ennél hosszabb időt is igénybe vehet. Amennyiben a munkaadó készpénzzel fizet,a sikeres fizetés után az alkalmazásban tudod megerősíteni a fizetést. Fontos, hogy a munkavégzés során mindig tartsd be a munkaadóval kötött megállapodást és a SkillTrade szabályait.")
                    .padding(10)
                    .font(.custom("OrelegaOne-Regular", size: 16))
                    .foregroundColor(.black)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.DesignSystem.descriptions)
                            .blur(radius: 4)

                    )
                    .padding(10)
                    .padding(.bottom, -2)
            }
            .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.DesignSystem.fokekszin)
                .shadow(color: Color(#colorLiteral(red: 0.1490196078, green: 0.3921568627, blue: 0.5568627451, alpha: 1)), radius: 16, x: 4, y: 4)
                .frame(height: 520)
            )
            .padding(5)
            .padding(.vertical, -5)
            
        }}


    
    // MARK: - Private Methods
    
    private func toggleSaveService() {
        guard let userId = userManager.currentUser?.id else { return }
        
        if isSaved {
            DatabaseManager.shared.removeService(service, userId: userId)
            isSaved = false
        } else {
            DatabaseManager.shared.saveService(service, userId: userId)
            isSaved = true
        }
    }
    
    private func checkSavedStatus() {
        guard let userId = userManager.currentUser?.id else { return }
        isSaved = DatabaseManager.shared.getSavedServices(userId: userId).contains { $0.id == service.id }
    }
}

struct ServiceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceDetailView(service: Service.preview)
    }
}

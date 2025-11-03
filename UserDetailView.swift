//
//  UserDetailView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//

//
//  UserDetailView.swift
//  SkillShare
//
//  Created by Czeglédi Ádi on 21/12/2024.
//
import SwiftUI
import DesignSystem

struct UserDetailView: View {
    let user: User

    @State private var showChat = false
    @StateObject private var userManager = UserManager.shared
    @State private var showLinks = false
    @State private var showPhotos = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statsSection
                skillsSection
                offersSection
                servicesSection
                badgesSection
                reviewsSection
            }
        }
        .sheet(isPresented: $showLinks) {
            UserDetailLinks(isPresented: $showLinks, user: user)
        }
        .sheet(isPresented: $showPhotos) {
            UserPhotosView(user: user)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { }
    }
}

// MARK: - Subviews broken out to reduce type-checking complexity
private extension UserDetailView {
    var profileHeader: some View {
        VStack(spacing: 12) {
            Image("profile")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .foregroundColor(.yellow)

            Text(user.name)
                .font(.title2)
                .bold()

            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                Text(user.location.city + ", " + user.location.country)
                    .font(.custom("Pacifico-Regular", size: 16))
            }

            HStack(spacing: 20) {
                Button(action: { showLinks = true }) {
                    Image("link")
                        .foregroundColor(.yellow)
                }

                Button(action: { showPhotos = true }) {
                    Image("photo")
                        .foregroundColor(.purple)
                }

                Button(action: { showChat = true }) {
                    Image("message_bubble")
                        .foregroundColor(.green)
                }
            }
            .font(.custom("Pacifico-Regular", size: 20))
            .padding(.top, 4)
        }
        .padding()
    }

    var statsSection: some View {
        HStack(spacing: 40) {
            VStack {
                Text(String(format: "%.1f", user.rating))
                    .font(.custom("OrelegaOne-Regular", size: 30))
                    .bold()
                StarRow(rating: Int(user.rating))
                Text(NSLocalizedString("rating", comment: ""))
                    .padding(.top, 1)
                    .font(.custom("OrelegaOne-Regular", size: 14))
                    .foregroundColor(.DesignSystem.descriptions)
            }

            VStack(spacing: 8) {
                Text("\(user.reviews.count)")
                    .font(.custom("OrelegaOne-Regular", size: 30))
                    .bold()
                Text(NSLocalizedString("rating", comment: ""))
                    .padding(.top, 1)
                    .font(.custom("OrelegaOne-Regular", size: 14))
                    .foregroundColor(.DesignSystem.descriptions)

                Text(NSLocalizedString("opinions", comment: ""))
                    .font(.custom("OrelegaOne-Regular", size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.DesignSystem.descriptions, lineWidth: 2)
                    )
                    .background(Color.DesignSystem.fokekszin)
                    .foregroundColor(Color.DesignSystem.descriptions)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(Color.DesignSystem.fokekszin))
        .cornerRadius(10)
        .padding(.horizontal)
        .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
    }

    var skillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("my-skills", comment: ""))
                .font(.custom("OrelegaOne-Regular", size: 20))
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(user.skills) { skill in
                        Text(skill.name)
                            .font(.custom("OrelegaOne-Regular", size: 14))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(Color.DesignSystem.descriptions))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
            }
        }
        .padding(.horizontal)
    }

    var offersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("my-offers", comment: ""))
                .font(.custom("OrelegaOne-Regular", size: 20))
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("what-i-offer", comment: ""))
                        .font(.custom("OrelegaOne-Regular", size: 14))

                    Text(user.servicesOffered)
                        .font(.custom("OrelegaOne-Regular", size: 14))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(Color.DesignSystem.descriptions))
                        .cornerRadius(8)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("what-i-advertise", comment: ""))
                        .font(.custom("OrelegaOne-Regular", size: 14))

                    Text(user.servicesAdvertised)
                        .font(.custom("OrelegaOne-Regular", size: 14))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(Color.DesignSystem.descriptions))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(Color.DesignSystem.fokekszin))
            .cornerRadius(10)
            .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
        }
        .padding(.horizontal)
    }

    var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("my-services", comment: ""))
                .font(.custom("OrelegaOne-Regular", size: 20))
                .padding(.horizontal)

            ForEach(user.pricing) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.description)
                            .font(.custom("OrelegaOne-Regular", size: 20))
                        Text("\(Int(item.price)) Ft")
                            .font(.custom("OrelegaOne-Regular", size: 15))
                            .foregroundColor(.yellow)
                    }
                    Spacer()
                    Button(action: { showChat = true }) {
                        Text(NSLocalizedString("send-message", comment: ""))
                            .font(.custom("OrelegaOne-Regular", size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.DesignSystem.descriptions, lineWidth: 2)
                            )
                            .background(Color.DesignSystem.fokekszin)
                            .foregroundColor(Color.DesignSystem.descriptions)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(Color.DesignSystem.fokekszin))
                .cornerRadius(10)
                .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
            }
        }
        .padding(.horizontal)
    }

    var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("my-badges", comment: ""))
                .font(.custom("OrelegaOne-Regular", size: 20))
                .padding(.horizontal)

            VStack(alignment: .leading) {
                Text(NSLocalizedString("soon", comment: ""))
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(Color.DesignSystem.fokekszin))
            .cornerRadius(10)
            .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
        }
        .padding(.horizontal)
    }

    var reviewsSection: some View {
        Group {
            if !user.reviews.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("rating", comment: ""))
                        .font(.custom("OrelegaOne-Regular", size: 20))
                        .padding(.horizontal)

                    ForEach(user.reviews) { review in
                        VStack(alignment: .leading, spacing: 8) {
                            StarRow(rating: Int(review.rating))
                            Text(review.text)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct StarRow: View {
    let rating: Int
    var body: some View {
        HStack {
            ForEach(0..<5) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .foregroundColor(.yellow)
            }
        }
    }
}

struct UserPhotosView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(user.photos, id: \.self) { photo in
                        Image(photo)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .navigationTitle("\(user.name) képei")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Bezárás") {
                        dismiss()
                    }
                    .foregroundColor(Color.DesignSystem.descriptions)
                }
            }
            .background(Color.white)
        }
    }
}

struct UserDetailLinks: View {
    @Binding var isPresented: Bool
    let user: User
    @State private var showMore = false
    @State private var buttonRotation = 0.0

    var body: some View {
        VStack(spacing: 20) {
            Text("Hivatkozások")
                .font(.custom("OrelegaOne-Regular", size: 24))
                .padding(.top)

            VStack(spacing: 15) {
                LinkButton(title: "Facebook", icon: "facebook", color: .blue) {
                    if let url = URL(string: "https://facebook.com/profile") {
                        UIApplication.shared.open(url)
                    }
                }

                LinkButton(title: "Instagram", icon: "instagram", color: .purple) {
                    if let url = URL(string: "https://instagram.com/profile") {
                        UIApplication.shared.open(url)
                    }
                }

                LinkButton(title: "X (Twitter)", icon: "x", color: .black) {
                    if let url = URL(string: "https://x.com/profile") {
                        UIApplication.shared.open(url)
                    }
                }

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showMore.toggle()
                        buttonRotation += 180
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Több")
                            .font(.custom("OrelegaOne-Regular", size: 16))
                            .foregroundColor(Color.DesignSystem.descriptions)
                        Image(systemName: "chevron.down")
                            .foregroundColor(Color.DesignSystem.descriptions)
                            .rotationEffect(.degrees(buttonRotation))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.DesignSystem.descriptions, lineWidth: 1.5)
                    )
                    .background(Color.DesignSystem.fokekszin)
                    .cornerRadius(8)
                }

                if showMore {
                    VStack(spacing: 15) {
                        LinkButton(title: "Snapchat", icon: "snapchat", color: .yellow) {
                            if let url = URL(string: "https://snapchat.com/add/profile") {
                                UIApplication.shared.open(url)
                            }
                        }

                        LinkButton(title: "Gmail", icon: "gmail", color: .red) {
                            if let url = URL(string: "mailto:user@gmail.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                        LinkButton(title: "Phone", icon: "telephone", color: .red) {
                            if let url = URL(string: "+3630/123-4567") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding()

            Button(action: { isPresented = false }) {
                Text("Bezárás")
                    .font(.custom("OrelegaOne-Regular", size: 16))
                    .foregroundColor(Color.DesignSystem.descriptions)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.DesignSystem.descriptions, lineWidth: 2)
                    )
                    .background(Color.DesignSystem.fokekszin)
                    .cornerRadius(8)
            }
            .padding(.bottom)
        }
        .frame(width: 300)
        .background(Color.DesignSystem.fokekszin)
        .cornerRadius(15)
        .shadow(radius: 16, x: 4, y: 4)
    }
}

struct LinkButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(Color.DesignSystem.descriptions)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.DesignSystem.descriptions)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.DesignSystem.descriptions, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
    }
}

struct ScaleButtonStyle3: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct UserDetailLinks_Previews: PreviewProvider {
    static var previews: some View {
        UserDetailLinks(isPresented: .constant(true), user: User.preview)
    }
}

struct UserDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UserDetailView(user: User.preview)
        }
    }
}

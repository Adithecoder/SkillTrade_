//
//  LoadingView2.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/3/25.
//

import SwiftUI
import DesignSystem

struct LoadingView2: View {
    @State private var isLoading = true
    @State private var progress: CGFloat = 0.0
    @State private var circleProgress: CGFloat = 0.0
    @State private var animationAmount: CGFloat = 1.0
    @State private var loadingText = NSLocalizedString("search-available-jobs", comment:"" )
    @State private var glowAnimation = false
    @State private var gradientRotation = 0.0
    @State private var meshAnimation = 0.0
    @State private var loadingPercentage = 0
    
    var body: some View {
        ZStack {
            // Mesh gradientes háttér
            MeshGradientBackground(meshAnimation: $meshAnimation)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Animált kör - HÁTTÉRREL AZONOS SZÍNEKKEL ÉS ANIMÁCIÓVAL
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0, to: circleProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .hex10(0x26648E),
                                    .hex10(0x4F8FC0),
                                    .hex10(0xE3BA6A),
                                    .hex10(0x26648E)
                                ]),
                                center: .center,
                                startAngle: .degrees(meshAnimation * 180 / .pi),
                                endAngle: .degrees(meshAnimation * 180 / .pi + 360)
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: -90))
                        .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 3)
                        .scaleEffect(animationAmount)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true),
                            value: animationAmount
                        )
                    
                    // Számláló a kör közepén
                    Text("\(loadingPercentage)%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 120, height: 120)

                
                // Dinamikus szövegek
                VStack(spacing: 10) {
                    Text("SkillTrade")
                        .font(.custom("Jellee", size: 28))
                        .foregroundColor(.white)
                    
                    Text(loadingText)
                        .font(.custom("Lexend", size:16))
                        .foregroundColor(.white.opacity(0.7))
                        .transition(.opacity)
                        .id(loadingText)
                }
                
                HStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        // Háttér
                        // Progress bar - HÁTTÉRREL AZONOS ANIMÁCIÓVAL
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .hex10(0x26648E),
                                        .hex10(0x4F8FC0),
                                        .hex10(0xE3BA6A)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 200 * progress, height: 8)
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .clear,
                                        .white.opacity(0.3),
                                        .clear
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .offset(x: glowAnimation ? 200 : -200)
                                .animation(
                                    Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
                                    value: glowAnimation
                                )
                            )
                            .mask(Capsule())
                    }
                    .frame(width: 200, alignment: .leading)
                    
                    // Progress százalék
                    Text("\(loadingPercentage)%")
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .monospacedDigit()
                }
                
                // Munka-specifikus elemek
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(.white)
                        Text(NSLocalizedString("search-available-jobs", comment:"" ))
                            .font(.custom("Lexend", size:12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.white)
                        Text(NSLocalizedString("income-opportunities", comment:"" ))
                            .font(.custom("Lexend", size:12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Skill-specifikus elem
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.white)
                        Text(NSLocalizedString("matching-skills", comment:"" ))
                            .font(.custom("Lexend", size:12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding()
            .background(
                Color.white.opacity(0.2)
                    .cornerRadius(30)
                    .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
            )
        }
        .onAppear {
            self.startLoading()
            
            // Kör animáció
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animationAmount = 1.1
            }
            
            // Glow animáció a progress bar-hoz
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowAnimation.toggle()
            }
            
            // Mesh háttér animáció
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                meshAnimation = 2 * .pi
            }
            
            // Szinkronizált betöltés indítása
            startSynchronizedLoading()
            
            // Dinamikus betöltési szövegek
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    loadingText = NSLocalizedString("analysing-data", comment:"" )
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    loadingText = NSLocalizedString("sync-options", comment:"" )
                }
            }
        }
    }
    
    func startLoading() {
        isLoading = true
    }
    
    func startSynchronizedLoading() {
        // Reset minden progress értéket
        progress = 0.0
        circleProgress = 0.0
        loadingPercentage = 0
        
        // Progress bar és kör EGYSZERRE animálása 6 másodperc alatt
        withAnimation(.easeInOut(duration: 6.0)) {
            progress = 1.0
            circleProgress = 1.0
        }
        
        // Számláló animáció - szinkronban a progress-szel
        // 6 másodperc / 100 lépés = 0.06 másodperces intervallum
        Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { timer in
            if loadingPercentage < 100 {
                loadingPercentage += 1
            } else {
                timer.invalidate()
                // Betöltés végén valamilyen akció
                loadingCompleted()
            }
        }
    }
    
    func loadingCompleted() {
        // Betöltés befejezve
        print("Betöltés befejezve - minden elem szinkronban ért véget!")
        
        // Kis késleltetés után valami történjen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Ide jöhet a navigáció vagy callback hívás
            // pl.: onLoadingComplete?()
        }
    }
}

// Mesh Gradientes Hátér View
// Mesh Gradientes Hátér View - Javított változat
struct MeshGradientBackground: View {
    @Binding var meshAnimation: Double
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = meshAnimation
                let currentTime = timeline.date.timeIntervalSinceReferenceDate
                
                // Mesh grid
                for y in stride(from: 0, through: Int(size.height), by: 60) {
                    for x in stride(from: 0, through: Int(size.width), by: 60) {
                        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
                        
                        // Dinamikus szín számítás
                        let hue = (Double(x + y) / 1000.0 + currentTime * 0.1).truncatingRemainder(dividingBy: 1.0)
                        let saturation = 0.7 + 0.2 * sin(currentTime + Double(x) * 0.01)
                        
                        let color = Color(
                            hue: hue,
                            saturation: saturation,
                            brightness: 0.8
                        )
                        
                        // Reszponzív pont méret
                        let radius = 80.0 + 30.0 * sin(currentTime * 0.5 + Double(x + y) * 0.01)
                        
                        // Radial gradient helyett egyszerű szín
                        var circlePath = Path()
                        circlePath.addEllipse(in: CGRect(
                            x: point.x - radius/2,
                            y: point.y - radius/2,
                            width: radius,
                            height: radius
                        ))
                        
                        context.fill(circlePath, with: .color(color.opacity(0.8)))
                    }
                }
            }
        }
        .blur(radius: 50)
        .overlay(
            LinearGradient(
                colors: [
                    .hex10(0x26648E).opacity(0.6),
                    .hex10(0xE3BA6A).opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                meshAnimation = 2 * .pi
            }
        }
    }
}
// Mesh Gradientes Kör
struct ContinuousMeshGradientCircle: View {
    @Binding var meshAnimation: Double
    let progress: CGFloat
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = meshAnimation
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 5
                
                var path = Path()
                
                // Körív rajzolása
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * Double(progress)),
                    clockwise: false
                )
                
                // Stroke gradienttel - use StrokeStyle to set lineCap
                let strokeStyle = StrokeStyle(lineWidth: 10, lineCap: .round)
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: generateMeshColors(time: time)),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    style: strokeStyle
                )
            }
        }
    }
    
    private func generateMeshColors(time: Double) -> [Color] {
        var colors: [Color] = []
        let steps = 10
        
        for i in 0..<steps {
            let hue = (Double(i) / Double(steps) + time / 8.0).truncatingRemainder(dividingBy: 1.0)
            let saturation = 0.7 + 0.2 * sin(time + Double(i) * 0.5)
            let brightness = 0.8 + 0.1 * cos(time * 0.5 + Double(i) * 0.3)
            
            colors.append(Color(
                hue: hue,
                saturation: saturation,
                brightness: brightness
            ))
        }
        
        return colors
    }
}
// Alternatív, egyszerűbb mesh gradientes megoldás
struct SimpleMeshBackground: View {
    @Binding var animation: Double
    
    var body: some View {
        ZStack {
            // Alap színek
            AngularGradient(
                gradient: Gradient(colors: [
                    .hex10(0x26648E),
                    .hex10(0x4F8FC0),
                    .hex10(0xE3BA6A),
                    .hex10(0x26648E)
                ]),
                center: .center,
                angle: .degrees(animation * 360)
            )
            
            // Mesh effektus overlay-el
            Canvas { context, size in
                let time = animation
                
                // Mesh grid rajzolása
                for y in stride(from: 0, through: Int(size.height), by: 40) {
                    for x in stride(from: 0, through: Int(size.width), by: 40) {
                        let noise = sin(time * 2 + Double(x + y) * 0.01)
                        let alpha = 0.1 + 0.05 * noise
                        
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: Double(x) - 20,
                                y: Double(y) - 20,
                                width: 40,
                                height: 40
                            )),
                            with: .color(.white.opacity(alpha))
                        )
                    }
                }
            }
            .blur(radius: 30)
        }
    }
}

extension Color {
    static func hex10(_ hexValue: UInt, alpha: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((hexValue >> 16) & 0xff) / 255,
            green: Double((hexValue >> 08) & 0xff) / 255,
            blue: Double((hexValue >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct LoadingView2_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView2()
            .previewDevice("iPhone 15 Pro")
    }
}

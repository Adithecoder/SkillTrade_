//
//  VerifiedBadge.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/30/25.
//


import SwiftUI
import DesignSystem

struct VerifiedBadge: View {
    let size: CGFloat
    
    init(size: CGFloat = 16) {
        self.size = size
    }
    
    var body: some View {
//        Image(systemName: "checkmark.seal.fill")
//            .resizable()
//            .scaledToFit()
//            .frame(width: size, height: size)
//            .foregroundColor(.blue)
//            .background(Color.white)
        
        Image("verified")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(.blue)
            .background(Color.white)
    }
}

// Kiterjesztés a View-re a könnyebb használathoz
extension View {
    func withVerifiedBadge(_ isVerified: Bool, size: CGFloat = 16) -> some View {
        HStack(spacing: 4) {
            self
            if isVerified {
                VerifiedBadge(size: size)
            }
        }
    }
}

struct DottedBadge: View {
    let size: CGFloat
    @State private var phase = 0.0
    @State private var gradientRotation = 0.0
    
    init(size: CGFloat = 16) {
        self.size = size
    }
    
    var body: some View {
        Circle()
            .strokeBorder(
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    dash: [4],
                    dashPhase: phase
                )
            )
            .foregroundStyle(
                AngularGradient(
                    gradient: Gradient(colors: [
                        .blue,
                        .cyan,
                        .mint,
                        .green,
                        .teal,
                        .blue
                    ]),
                    center: .center,
                    angle: .degrees(gradientRotation)
                )
            )
            .frame(width: size, height: size)
            .drawingGroup()
            .onAppear {
                // Késleltetés a renderelés elosztásához
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.5)) {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase -= 20
                    }
                    
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        gradientRotation = 360
                    }
                }
            }
    }
}

extension View {
    func rainbow() -> some View {
        self.modifier(RainbowModifier())
    }
}


struct RainbowModifier: ViewModifier {
    @State private var gradientRotation = 0.0
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                AngularGradient(
                    gradient: Gradient(colors: [
                        .blue,
                        .cyan,
                        .mint,
                        .green,
                        .teal,
                        .blue
                    ]),
                    center: .center,
                    angle: .degrees(gradientRotation)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    gradientRotation = 360
                }
            }
    }
}


struct RainbowBackground: ViewModifier {
    @State private var gradientRotation = 0.0
    
    func body(content: Content) -> some View {
        content
            .background(
                AngularGradient(
                    gradient: Gradient(colors: [
                        .blue,
                        .cyan,
                        .mint,
                        .green,
                        .teal,
                        .blue
                    ]),
                    center: .center,
                    angle: .degrees(gradientRotation)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    gradientRotation = 360
                }
            }
    }
}

extension View {
    func rainbowBackground() -> some View {
        self.modifier(RainbowBackground())
    }
}

// Használat - szuper egyszerű:

// Használat:
// Használat:
#Preview {
    VerifiedBadge(size: 20)
    
    DottedBadge(size:100)
    
Text("Példa")
        .rainbowBackground()
    
    Text("Hello Rainbow!")
        .font(.title)
        .fontWeight(.bold)
        .rainbow()
}

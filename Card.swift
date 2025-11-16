import SwiftUI

// Define the Card model
struct Card2: Identifiable, Hashable {
    let id = UUID()
    let text: String
}

// Sample data
let cards2 = [
    Card2(text: "Card 1"),
    Card2(text: "Card 2"),
    Card2(text: "Card 3"),
    Card2(text: "Card 4")
]

struct CardView2: View {
    @State private var activeCard: Card2?
    @State private var scrollPosition: UUID?
    
    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(cards2) { card2 in
                        cardView2(for: card2)
                    }
                    .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition)
            .scrollIndicators(.never)
            .onChange(of: scrollPosition) { oldValue, newValue in
                // Update activeCard when scroll position changes
                if let newId = newValue {
                    activeCard = cards2.first(where: { $0.id == newId })
                }
            }
            
            pagingControl
        }
        .onAppear {
            activeCard = cards2.first
            scrollPosition = cards2.first?.id
        }
    }
    
    func cardView2(for card2: Card2) -> some View {
        Text(card2.text)
            .frame(maxWidth: .infinity, maxHeight: 200)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(10)
            .shadow(radius: 10)
            .padding()
            .containerRelativeFrame(.horizontal)
    }
    
    var pagingControl: some View {
        HStack {
            ForEach(cards2) { card2 in
                Circle()
                    .fill(activeCard?.id == card2.id ? Color.blue : Color.gray)
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeCard = card2
                            scrollPosition = card2.id
                        }
                    }
            }
        }
        .padding()
    }
}

struct Animation2: View {
    @State private var isPresented = false
    
    var body: some View {
        VStack(spacing: 50){
            Image(systemName: isPresented ? "checkmark.circle.fill" : "faceid")
                .font(.system(size: 100))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle( isPresented ? .green : .black)
            
            Text(isPresented ? "Sikeres fizetés!": "")
                .font(.custom("Lexend", size:20))
            Button("Show symbol", action: { isPresented = true })
        }
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView2()
        Animation2()
    }
}

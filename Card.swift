import SwiftUI

// Define the Card model
struct Card: Identifiable, Hashable {
    let id = UUID()
    let text: String
}

// Sample data
let cards = [
    Card(text: "Card 1"),
    Card(text: "Card 2"),
    Card(text: "Card 3"),
    Card(text: "Card 4")
]

struct CardView: View {
    @State private var activeCard: Card?
    @State private var scrollPosition: UUID?
    
    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(cards) { card in
                        cardView(for: card)
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
                    activeCard = cards.first(where: { $0.id == newId })
                }
            }
            
            pagingControl
        }
        .onAppear {
            activeCard = cards.first
            scrollPosition = cards.first?.id
        }
    }
    
    func cardView(for card: Card) -> some View {
        Text(card.text)
            .frame(maxWidth: .infinity, maxHeight: 200)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(10)
            .shadow(radius: 10)
            .padding()
            .containerRelativeFrame(.horizontal)
    }
    
    var pagingControl: some View {
        HStack {
            ForEach(cards) { card in
                Circle()
                    .fill(activeCard?.id == card.id ? Color.blue : Color.gray)
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeCard = card
                            scrollPosition = card.id
                        }
                    }
            }
        }
        .padding()
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView()
    }
}

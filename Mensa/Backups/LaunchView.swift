import SwiftUI

struct LaunchView: View {
    @Binding var isActive: Bool
    @State private var scale: CGFloat = 1   // 0.95 = départ légèrement réduit
    @State private var opacity: Double = 1   // 0.0 = départ transparent

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("logo_mensa")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 150)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Text("L'agenda Mensa Île-de-France")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .opacity(opacity)
            }
            .onAppear {
                // 1️⃣ Animation d'entrée pour adoucir le passage du LaunchScreen
                withAnimation(.easeOut(duration: 1)) { // 1s avant bascule en fondu fluide vers LaunchView
                    opacity = 1.0
                    scale = 1.0
                }
                
                // 2️⃣ Heartbeat
                heartbeatAnimation()
                
                // 3️⃣ Transition vers l'app
                transitionToApp()
            }
        }
    }

    // MARK: - Heartbeat animation
    private func heartbeatAnimation() {
        let baseScale: CGFloat = 1.0 // taille normale de l'image
        let peakScale: CGFloat = 1.1 // 10% de taille supplémentaire

        withAnimation(.easeOut(duration: 0.15)) { scale = peakScale } // battement de 0.15s en montée
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.45)) { scale = baseScale } // battement de 0.45s en descente

            // Pause courte avant 2e battement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { // 0.8s entre 2 battements
                withAnimation(.easeOut(duration: 0.15)) { scale = peakScale } // battement de 0.15s en montée
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeIn(duration: 0.45)) { scale = baseScale } // battement de 0.45s en descente
                }
            }
        }
    }
    
    // MARK: - Transition douce vers l'app
    private func transitionToApp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // 1s avant bascule en fondu fluide vers l'app
            withAnimation(.easeInOut(duration: 1.2)) {
                opacity = 0.0    // fondu
                scale = 0.95     // léger rétrécissement
            }
            // Masquer complètement LaunchView après animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isActive = false
            }
        }
    }
}

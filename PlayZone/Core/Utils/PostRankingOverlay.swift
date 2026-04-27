import SwiftUI

struct PostRankingOverlay: View {
    let onNewGame: () -> Void
    let onMenu:    () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .onTapGesture { onNewGame() }

            VStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(hex: "EAB308"))

                Text("¿Qué hacemos ahora?")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Button(action: onNewGame) {
                    Text("Nueva partida")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "6366F1"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onMenu) {
                    Text("Volver al menú")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "1E293B"))
                        .foregroundStyle(Color(hex: "94A3B8"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .background(Color(hex: "0F172A"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.5), radius: 24)
            .padding(.horizontal, 32)
        }
    }
}

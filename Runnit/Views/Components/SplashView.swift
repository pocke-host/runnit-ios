import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("RUNNIT")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .tracking(6)
            ProgressView()
                .tint(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RunnitTheme.ink)
        .foregroundStyle(.white)
        .ignoresSafeArea()
    }
}

import SwiftUI

struct SplashView: View {
    @State private var startAnimation: Bool = false
    
    // 티노 브랜드 컬러
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        ZStack {
            // 1. 배경색
            brandColor
                .ignoresSafeArea()
            
            // 2. 로고 및 텍스트
            VStack(spacing: 20) {
                // 로고 아이콘 (학사모 모양 추천)
                Image(systemName: "graduationcap.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.white)
                
                // 앱 이름
                Text("Teacher's Knock")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("교사가 되는 문을 두드리다")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .scaleEffect(startAnimation ? 1.0 : 0.8) // 작았다가 커지는 효과
            .opacity(startAnimation ? 1.0 : 0.0)     // 투명했다가 나타나는 효과
        }
        .onAppear {
            // 0.3초 동안 부드럽게 등장
            withAnimation(.easeOut(duration: 1.0)) {
                startAnimation = true
            }
        }
    }
}

#Preview {
    SplashView()
}

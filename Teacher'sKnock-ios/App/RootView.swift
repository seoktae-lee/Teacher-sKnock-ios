import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSplash: Bool = true // 스플래시 표시 여부
    
    var body: some View {
        ZStack {
            if showSplash {
                // 1. 스플래시 화면
                SplashView()
                    .transition(.opacity) // 사라질 때 페이드 아웃
            } else {
                // 2. 스플래시 종료 후: 로그인 상태에 따라 분기
                if authManager.isLoggedIn {
                    MainTabView() // 메인 화면
                } else {
                    LoginView()   // 로그인 화면
                }
            }
        }
        .onAppear {
            // 2초 뒤에 스플래시를 끄고 메인 로직으로 진입
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }
}

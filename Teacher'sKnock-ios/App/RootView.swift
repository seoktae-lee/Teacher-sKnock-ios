import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    // ✨ SwiftData의 핵심 도구(Context) 가져오기
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        Group {
            if authManager.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            // ✨ [핵심] 여기서 매니저들을 연결하고, SwiftData 권한도 줍니다.
            print("RootView: 매니저 및 데이터 연결 시도")
            authManager.setup(settingsManager: settingsManager, modelContext: modelContext)
        }
    }
}

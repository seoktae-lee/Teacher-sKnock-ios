import SwiftUI
import SwiftData
import FirebaseCore

@main
struct TeachersKnock_iosApp: App {
    // 1. 매니저들을 StateObject로 생성 (앱이 살아있는 동안 유지됨)
    @StateObject private var authManager = AuthManager()
    @StateObject private var settingsManager = SettingsManager()
    
    init() {
        // Firebase 초기화는 앱 시작 시 한 번만
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                // 2. View 계층 구조 전체에 매니저 객체 제공
                .environmentObject(authManager)
                .environmentObject(settingsManager)
                .onAppear {
                    // 🔥 [핵심] AuthManager에게 SettingsManager를 알려주어 연결합니다.
                    // 이렇게 해야 로그인/로그아웃 시 데이터 로드/초기화 명령이 전달됩니다.
                    authManager.setup(settingsManager: settingsManager)
                }
        }
        // SwiftData 컨테이너 설정 (Goal, ScheduleItem, StudyRecord)
        .modelContainer(for: [Goal.self, ScheduleItem.self, StudyRecord.self])
    }
}

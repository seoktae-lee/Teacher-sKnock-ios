import SwiftUI
import SwiftData
import FirebaseCore

@main
struct TeachersKnock_iosApp: App {
    // 앱 생명주기 동안 살아있는 매니저들
    @StateObject private var authManager = AuthManager()
    @StateObject private var settingsManager = SettingsManager()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                // 환경 객체 주입
                .environmentObject(authManager)
                .environmentObject(settingsManager)
                // ❌ 주의: 여기서 authManager.setup(...)을 호출하면 안 됩니다!
                // RootView.swift에서 처리하도록 변경했습니다.
        }
        // SwiftData 컨테이너 설정
        .modelContainer(for: [Goal.self, ScheduleItem.self, StudyRecord.self])
    }
}

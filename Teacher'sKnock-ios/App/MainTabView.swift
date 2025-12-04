import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            GoalListView(userId: Auth.auth().currentUser?.uid ?? "")
                .tabItem { Label("홈", systemImage: "house.fill") }
            
            // ✨ [수정] 괄호 안을 비웠습니다.
            PlannerView()
                .tabItem { Label("플래너", systemImage: "calendar") }
            
            TimerView()
                .tabItem { Label("타이머", systemImage: "timer") }
            
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
        }
        .accentColor(Color(red: 0.35, green: 0.65, blue: 0.95))
    }
}

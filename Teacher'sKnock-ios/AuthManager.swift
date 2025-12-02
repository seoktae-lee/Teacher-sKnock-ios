import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthManager: ObservableObject {
    
    @Published var isLoggedIn: Bool = false
    @Published var userNickname: String = "나"
    
    var settingsManager: SettingsManager?
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        registerAuthStateListener()
    }
    
    // SettingsManager를 주입받아 연결하는 함수 (이전 단계에서 추가됨)
    func setup(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        print("AuthManager: SettingsManager 연결 완료.")
    }
    
    private func registerAuthStateListener() {
        // ... (이 부분은 수정 없음)
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            // 안전한 self 언래핑
            guard let self = self else { return }
            
            let isUserVerified = user?.isEmailVerified ?? false
            
            if let user = user, isUserVerified {
                // ... (로그인 로직)
                self.isLoggedIn = true
                self.fetchUserNickname(uid: user.uid)
                self.settingsManager?.fetchSettings(uid: user.uid)
                
            } else {
                // ... (로그아웃 로직)
                self.isLoggedIn = false
                self.userNickname = "나"
                self.settingsManager?.reset()
            }
        }
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func fetchUserNickname(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { [weak self] document, error in
            
            // 🔥 [수정된 부분] weak self를 안전하게 언래핑합니다.
            guard let self = self else { return }
            
            if let document = document, document.exists {
                DispatchQueue.main.async {
                    self.userNickname = document.data()?["nickname"] as? String ?? "나"
                }
            }
        }
    }
}

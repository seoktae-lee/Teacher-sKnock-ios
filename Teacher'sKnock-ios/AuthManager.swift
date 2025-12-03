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
    
    func setup(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        print("AuthManager: SettingsManager 연결 완료.")
    }
    
    private func registerAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            
            // NOTE: 테스트를 위해 isEmailVerified 체크는 잠시 생략 가능
            // let isUserVerified = user?.isEmailVerified ?? false
            let isUserVerified = true // (개발 편의상 true로 둠, 실제 배포 시엔 user?.isEmailVerified ?? false 로 변경 권장)
            
            if let user = user, isUserVerified {
                print("AuthManager: 로그인 감지")
                self.isLoggedIn = true
                self.fetchUserNickname(uid: user.uid)
                self.settingsManager?.fetchSettings(uid: user.uid)
            } else {
                print("AuthManager: 로그아웃 상태")
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
            guard let self = self else { return }
            if let document = document, document.exists {
                DispatchQueue.main.async {
                    self.userNickname = document.data()?["nickname"] as? String ?? "나"
                }
            }
        }
    }
    
    // ✨ [NEW] 회원탈퇴 기능
    func deleteAccount(completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        
        // 1. Firestore 유저 데이터 삭제
        let db = Firestore.firestore()
        db.collection("users").document(uid).delete { error in
            if let error = error {
                completion(false, error)
                return
            }
            
            // 2. Firebase Auth 계정 삭제
            user.delete { error in
                if let error = error {
                    // 로그인한지 오래되면 재인증 필요할 수 있음
                    completion(false, error)
                } else {
                    // 성공 시 리스너가 알아서 로그아웃 처리함
                    print("AuthManager: 계정 삭제 완료")
                    completion(true, nil)
                }
            }
        }
    }
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftData // ✨ 필수!

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userNickname: String = "나"
    
    var settingsManager: SettingsManager?
    var modelContext: ModelContext?
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() { registerAuthStateListener() }
    
    // ✨ setup 함수: 인자 2개 (설정매니저, 모델컨텍스트)
    func setup(settingsManager: SettingsManager, modelContext: ModelContext) {
        self.settingsManager = settingsManager
        self.modelContext = modelContext
        print("AuthManager: 설정 및 데이터 연결 완료")
    }
    
    private func registerAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            
            if let user = user {
                self.checkUserExistsInFirestore(uid: user.uid) { exists in
                    if exists {
                        self.isLoggedIn = true
                        self.fetchUserNickname(uid: user.uid)
                        self.settingsManager?.fetchSettings(uid: user.uid)
                        // 로그인 성공 시 데이터 복구 시도
                        if let context = self.modelContext {
                            self.checkAndRestoreData(uid: user.uid, context: context)
                        }
                    } else {
                        self.isLoggedIn = false
                    }
                }
            } else {
                self.isLoggedIn = false
                self.userNickname = "나"
                self.settingsManager?.reset()
            }
        }
    }
    
    deinit {
        if let handle = handle { Auth.auth().removeStateDidChangeListener(handle) }
    }
    
    @MainActor
    private func checkAndRestoreData(uid: String, context: ModelContext) {
        // 로컬 데이터가 비었으면 서버에서 가져오는 로직 (FirestoreSyncManager 사용)
        do {
            let descriptor = FetchDescriptor<ScheduleItem>(predicate: #Predicate { $0.ownerID == uid })
            let count = try context.fetchCount(descriptor)
            if count == 0 {
                print("AuthManager: 로컬 데이터 없음 -> 서버 복구 시작")
                FirestoreSyncManager.shared.restoreData(context: context, uid: uid) {
                    print("AuthManager: 데이터 동기화 완료")
                }
            }
        } catch {
            print("데이터 확인 중 오류: \(error)")
        }
    }
    
    private func checkUserExistsInFirestore(uid: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { doc, _ in
            completion(doc?.exists ?? false)
        }
    }
    
    private func fetchUserNickname(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] doc, _ in
            guard let self = self else { return }
            if let doc = doc, doc.exists {
                DispatchQueue.main.async {
                    self.userNickname = doc.data()?["nickname"] as? String ?? "나"
                }
            }
        }
    }
    
    func deleteAccount(completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        Firestore.firestore().collection("users").document(uid).delete { error in
            if let error = error { completion(false, error); return }
            user.delete { error in completion(error == nil, error) }
        }
    }
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftData

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userNickname: String = "나"
    
    var settingsManager: SettingsManager?
    var modelContext: ModelContext?
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() { registerAuthStateListener() }
    
    func setup(settingsManager: SettingsManager, modelContext: ModelContext) {
        self.settingsManager = settingsManager
        self.modelContext = modelContext
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.settingsManager?.reset()
        } catch { print("로그아웃 실패: \(error)") }
    }
    
    private func registerAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user {
                self.checkUserExistsInFirestore(uid: user.uid) { exists in
                    if exists {
                        self.isLoggedIn = true
                        self.fetchUserData(uid: user.uid)
                        self.settingsManager?.loadSettings(for: user.uid)
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
    
    deinit { if let handle = handle { Auth.auth().removeStateDidChangeListener(handle) } }
    
    // ... (checkAndRestoreData, checkUserExistsInFirestore, fetchUserData는 기존 코드 유지)
    // 아래 코드를 위해 생략하지 않고 포함해야 한다면, 이전에 드린 코드의 해당 부분들을 그대로 두시면 됩니다.
    @MainActor
    private func checkAndRestoreData(uid: String, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<ScheduleItem>(predicate: #Predicate { $0.ownerID == uid })
            let count = try context.fetchCount(descriptor)
            if count == 0 {
                FirestoreSyncManager.shared.restoreData(context: context, uid: uid) {}
            }
        } catch { print("데이터 확인 오류: \(error)") }
    }
    
    private func checkUserExistsInFirestore(uid: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { doc, _ in completion(doc?.exists ?? false) }
    }
    
    private func fetchUserData(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] doc, _ in
            guard let self = self, let doc = doc, doc.exists, let data = doc.data() else { return }
            DispatchQueue.main.async {
                self.userNickname = data["nickname"] as? String ?? "나"
                if let univName = data["university"] as? String { self.settingsManager?.setUniversity(fromName: univName) }
                if let officeName = data["targetOffice"] as? String { self.settingsManager?.setOffice(fromName: officeName) }
            }
        }
    }
    
    // ✨ [핵심 수정] 회원 탈퇴 로직 (강력한 삭제)
    func deleteAccount(completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let db = Firestore.firestore()
        
        // 1. Firestore 데이터 삭제 (users/{uid})
        // (주의: 하위 컬렉션인 settings는 클라이언트에서 삭제되지 않을 수 있으나,
        // 계정이 삭제되면 접근 불가능하므로 MVP에서는 user 문서 삭제로 충분합니다)
        db.collection("users").document(uid).delete { error in
            if let error = error {
                print("🔥 Firestore 삭제 실패: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            // 2. Authentication 계정 영구 삭제
            user.delete { error in
                if let error = error {
                    // 재인증 필요 에러 등 처리
                    print("🔥 Auth 계정 삭제 실패: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("✅ 회원 탈퇴 완료 (Auth + Firestore)")
                    // 로컬 상태 초기화
                    DispatchQueue.main.async {
                        self.isLoggedIn = false
                        self.settingsManager?.reset()
                    }
                    completion(true, nil)
                }
            }
        }
    }
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("학습 설정")) {
                    NavigationLink(destination: SubjectSelectView()) {
                        HStack {
                            Text("선호 과목 설정")
                            Spacer()
                            Text("\(settingsManager.favoriteSubjects.count)개 선택됨")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("계정")) {
                    if let user = Auth.auth().currentUser {
                        HStack {
                            Text("이메일")
                            Spacer()
                            Text(user.email ?? "알 수 없음")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section {
                    Button("로그아웃") {
                        showLogoutAlert = true
                    }
                    .foregroundColor(.blue)
                }
                .alert("로그아웃", isPresented: $showLogoutAlert) {
                    Button("취소", role: .cancel) { }
                    Button("로그아웃", role: .destructive) {
                        logout()
                    }
                } message: {
                    Text("정말 로그아웃 하시겠습니까?")
                }
                
                Section {
                    Button("회원 탈퇴") {
                        showDeleteAlert = true
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Teacher's Knock 회원 탈퇴")
                } footer: {
                    Text("탈퇴 시 모든 데이터가 영구적으로 삭제됩니다.")
                }
                .alert("회원 탈퇴", isPresented: $showDeleteAlert) {
                    Button("취소", role: .cancel) { }
                    Button("탈퇴하기", role: .destructive) {
                        deleteAccount()
                    }
                } message: {
                    Text("정말로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.")
                }
            }
            .navigationTitle("설정")
            .alert("알림", isPresented: $showAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // ✨ 로그아웃 함수 수정
    func logout() {
        do {
            try Auth.auth().signOut()
            authManager.isLoggedIn = false
            settingsManager.reset() // 명시적 초기화
        } catch let error {
            print("로그아웃 실패: \(error.localizedDescription)")
        }
    }
    
    // ✨ 회원 탈퇴 함수 수정
    func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let db = Firestore.firestore()
        
        db.collection("users").document(uid).delete { error in
            if let error = error {
                alertMessage = "데이터 삭제 실패: \(error.localizedDescription)"
                showAlert = true
                return
            }
            user.delete { error in
                if let error = error {
                    alertMessage = "계정 삭제 실패: 재로그인 후 시도해주세요."
                    showAlert = true
                } else {
                    authManager.isLoggedIn = false
                    settingsManager.reset() // 명시적 초기화
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(SettingsManager())
}

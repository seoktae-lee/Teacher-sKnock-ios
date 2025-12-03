import SwiftUI
import FirebaseAuth
import SwiftData // ✨ 데이터 삭제를 위해 필요

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    // ✨ 로컬 데이터 삭제를 위한 컨텍스트
    @Environment(\.modelContext) private var modelContext
    
    // 탈퇴 경고창 상태
    @State private var showDeleteAlert = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    var body: some View {
        NavigationStack {
            List {
                // 1. 프로필 섹션
                Section {
                    HStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray.opacity(0.5))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.userNickname)
                                .font(.headline)
                            if let email = Auth.auth().currentUser?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 2. 학습 설정 섹션
                Section(header: Text("학습 설정")) {
                    NavigationLink(destination: SubjectSelectView()) {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.blue)
                            Text("선호 과목 설정")
                        }
                    }
                    
                    NavigationLink(destination: Text("준비 중인 기능입니다.")) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.red)
                            Text("디데이/목표 관리")
                        }
                    }
                }
                
                // 3. 앱 정보 섹션
                Section(header: Text("앱 정보")) {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(appVersion).foregroundColor(.gray)
                    }
                    
                    Link(destination: URL(string: "https://www.google.com")!) {
                        Text("이용약관")
                    }
                    Link(destination: URL(string: "https://www.google.com")!) {
                        Text("개인정보 처리방침")
                    }
                }
                
                // 4. 계정 관리 섹션
                Section {
                    Button(action: signOut) {
                        Text("로그아웃")
                            .foregroundColor(.primary)
                    }
                    
                    // ✨ 회원탈퇴 버튼 (빨간색)
                    Button(role: .destructive, action: {
                        showDeleteAlert = true
                    }) {
                        Text("회원탈퇴")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("설정")
            // ✨ 회원탈퇴 경고창
            .alert("정말 탈퇴하시겠습니까?", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("탈퇴하기", role: .destructive) {
                    performDeleteAccount()
                }
            } message: {
                Text("탈퇴 시 귀하의 모든 학습 기록, 일정, 설정 정보가 즉시 영구 삭제되며 복구할 수 없습니다.")
            }
            // 에러 발생 시 알림
            .alert("오류 발생", isPresented: $showErrorAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func signOut() {
        try? Auth.auth().signOut()
    }
    
    // ✨ 실제 탈퇴 로직
    private func performDeleteAccount() {
        // 1. SwiftData(로컬 데이터) 전체 삭제
        do {
            try modelContext.delete(model: ScheduleItem.self)
            try modelContext.delete(model: StudyRecord.self)
            try modelContext.delete(model: Goal.self)
            print("SettingsView: 로컬 데이터 삭제 완료")
        } catch {
            print("SettingsView: 로컬 데이터 삭제 실패 - \(error)")
        }
        
        // 2. 서버 계정 삭제 요청
        authManager.deleteAccount { success, error in
            if !success {
                errorMessage = error?.localizedDescription ?? "알 수 없는 오류가 발생했습니다."
                showErrorAlert = true
            } else {
                // 성공하면 AuthManager가 자동으로 로그아웃 상태로 전환시킴
                print("회원탈퇴 최종 완료")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(SettingsManager())
}

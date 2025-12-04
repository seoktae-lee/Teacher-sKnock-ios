import SwiftUI
import FirebaseAuth // ✨ 필수!
import SwiftData    // ✨ 필수!

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var showDeleteAlert = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .resizable().frame(width: 50, height: 50).foregroundColor(.gray.opacity(0.5))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.userNickname).font(.headline)
                            if let email = Auth.auth().currentUser?.email {
                                Text(email).font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("학습 설정")) {
                    NavigationLink(destination: SubjectSelectView()) {
                        HStack { Image(systemName: "book.closed.fill").foregroundColor(.blue); Text("선호 과목 설정") }
                    }
                    NavigationLink(destination: Text("준비 중인 기능입니다.")) {
                        HStack { Image(systemName: "target").foregroundColor(.red); Text("디데이/목표 관리") }
                    }
                }
                
                Section(header: Text("앱 정보")) {
                    HStack { Text("버전"); Spacer(); Text(appVersion).foregroundColor(.gray) }
                    Link("이용약관", destination: URL(string: "https://www.google.com")!)
                    Link("개인정보 처리방침", destination: URL(string: "https://www.google.com")!)
                }
                
                Section {
                    Button("로그아웃") { try? Auth.auth().signOut() }.foregroundColor(.primary)
                    Button("회원탈퇴") { showDeleteAlert = true }.foregroundColor(.red)
                }
            }
            .navigationTitle("설정")
            .alert("정말 탈퇴하시겠습니까?", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("탈퇴하기", role: .destructive) { performDeleteAccount() }
            } message: {
                Text("탈퇴 시 모든 학습 기록과 설정이 영구 삭제되며, 복구할 수 없습니다.")
            }
            .alert("오류", isPresented: $showErrorAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func performDeleteAccount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            let scheduleDescriptor = FetchDescriptor<ScheduleItem>(predicate: #Predicate { $0.ownerID == uid })
            let schedules = try modelContext.fetch(scheduleDescriptor)
            for item in schedules { modelContext.delete(item) }
            
            let recordDescriptor = FetchDescriptor<StudyRecord>(predicate: #Predicate { $0.ownerID == uid })
            let records = try modelContext.fetch(recordDescriptor)
            for record in records { modelContext.delete(record) }
            
            let goalDescriptor = FetchDescriptor<Goal>(predicate: #Predicate { $0.ownerID == uid })
            let goals = try modelContext.fetch(goalDescriptor)
            for goal in goals { modelContext.delete(goal) }
            
            print("SettingsView: 로컬 데이터 삭제 완료")
        } catch {
            print("SettingsView: 삭제 실패 - \(error)")
        }
        
        authManager.deleteAccount { success, error in
            if !success {
                errorMessage = error?.localizedDescription ?? "알 수 없는 오류"
                showErrorAlert = true
            }
        }
    }
}

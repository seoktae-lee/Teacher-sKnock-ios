import SwiftUI
import FirebaseAuth

struct SubjectSelectView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    // 모든 과목 (자율선택 제외)
    let allSubjects = SubjectName.allCases.filter { $0 != .selfStudy }
    
    // ✨ 현재 로그인한 내 ID (이게 있어야 내 사물함에 저장함)
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        List {
            Section(header: Text("자주 공부하는 과목을 최대 8개 선택해주세요."),
                    footer: Text("\(settingsManager.favoriteSubjects.count) / 8 선택됨")) {
                
                ForEach(allSubjects) { subject in
                    HStack {
                        Text(subject.localizedName)
                            .foregroundColor(.primary)
                        Spacer()
                        
                        // 내가 선택한 목록에 있으면 체크 표시
                        if settingsManager.favoriteSubjects.contains(subject) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray.opacity(0.3))
                                .font(.title3)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSubject(subject)
                    }
                }
            }
        }
        .navigationTitle("선호 과목 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func toggleSubject(_ subject: SubjectName) {
        // 로그인이 안 되어 있으면 저장 불가
        guard let uid = currentUserId else { return }
        
        var newFavorites = settingsManager.favoriteSubjects
        
        if let index = newFavorites.firstIndex(of: subject) {
            // 이미 있으면 해제
            newFavorites.remove(at: index)
        } else {
            // 없으면 추가 (8개 제한)
            if newFavorites.count < 8 {
                newFavorites.append(subject)
            }
        }
        
        // ✨ 변경된 리스트를 서버에 즉시 저장! (앱 꺼도 유지됨)
        settingsManager.saveFavoriteSubjects(uid: uid, newFavorites)
    }
}

#Preview {
    SubjectSelectView()
        .environmentObject(SettingsManager())
}

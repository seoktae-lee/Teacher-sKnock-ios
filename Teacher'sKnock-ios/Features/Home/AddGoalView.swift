import SwiftUI
import SwiftData
import FirebaseAuth

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // ✨ ViewModel 연결 (이제 데이터와 로직은 얘가 담당)
    @StateObject private var viewModel = GoalViewModel()
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("목표 이름")) {
                    // viewModel.title에 바로 연결
                    TextField("예: 2026학년도 초등 임용", text: $viewModel.title)
                }
                
                Section(header: Text("디데이 날짜")) {
                    DatePicker("날짜 선택", selection: $viewModel.targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accentColor(brandColor)
                }
                
                // 캐릭터 육성 옵션 섹션
                Section {
                    Toggle(isOn: $viewModel.useCharacter) {
                        VStack(alignment: .leading) {
                            Text("티노 캐릭터 함께 키우기")
                                .font(.headline)
                            Text("목표 기간에 맞춰 캐릭터가 성장합니다.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(brandColor)
                }
            }
            .navigationTitle("새 목표 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveGoal()
                    }
                    .foregroundColor(brandColor)
                    .disabled(viewModel.title.isEmpty)
                }
            }
        }
    }
    
    // ViewModel에게 저장 요청
    private func saveGoal() {
        guard let user = Auth.auth().currentUser else { return }
        
        viewModel.addGoal(ownerID: user.uid, context: modelContext)
        dismiss()
    }
}

#Preview {
    AddGoalView()
}

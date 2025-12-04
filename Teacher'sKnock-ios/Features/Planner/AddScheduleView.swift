import SwiftUI
import SwiftData
import FirebaseAuth

struct AddScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // ✨ ViewModel 연결 (StateObject로 생성)
    @StateObject private var viewModel = PlannerViewModel()
    
    // UI 입력값은 View가 관리해도 됨 (임시 데이터니까)
    @State private var title = ""
    @State private var details = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasReminder = false
    
    // 현재 사용자 ID
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    init() {
        // 시간 초기화 로직 (현재 시간 기준 다음 정각/30분)
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = components.minute ?? 0
        components.minute = minute < 30 ? 30 : 0
        if minute >= 30 { components.hour = (components.hour ?? 0) + 1 }
        
        let roundedStart = calendar.date(from: components) ?? now
        let oneHourLater = roundedStart.addingTimeInterval(3600)
        
        _startDate = State(initialValue: roundedStart)
        _endDate = State(initialValue: oneHourLater)
    }
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("일정 내용")) {
                    TextField("일정 제목 (예: 교육학 암기)", text: $title)
                        .font(.headline)
                    
                    TextField("상세 메모 (선택)", text: $details)
                }
                
                Section(header: Text("시간 설정")) {
                    DatePicker("시작", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        .tint(brandColor)
                    
                    DatePicker("종료", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                        .tint(brandColor)
                }
                
                Section {
                    Toggle("시작 전 알림 받기", isOn: $hasReminder)
                        .tint(brandColor)
                }
            }
            .navigationTitle("새 일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveSchedule()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(brandColor)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    // ✨ ViewModel에게 일을 시키는 함수
    private func saveSchedule() {
        viewModel.addSchedule(
            title: title,
            details: details,
            startDate: startDate,
            endDate: endDate,
            hasReminder: hasReminder,
            ownerID: currentUserId,
            context: modelContext
        )
        dismiss()
    }
}

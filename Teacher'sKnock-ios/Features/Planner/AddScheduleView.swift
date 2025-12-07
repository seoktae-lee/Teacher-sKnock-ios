import SwiftUI
import SwiftData
import FirebaseAuth

struct AddScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedSubject: String = "교육학"
    
    let subjects = ["교육학", "전공", "한국사", "기타"]
    
    // ✨ [핵심 해결] 외부에서 날짜를 받아오는 생성자 추가
    // 이 코드가 있어야 DailyDetailView의 "Argument passed to call..." 오류가 사라집니다.
    init(selectedDate: Date = Date()) {
        let now = Date()
        let calendar = Calendar.current
        
        // 선택된 날짜의 연/월/일 + 현재 시간
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: now)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        let start = calendar.date(from: components) ?? selectedDate
        let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("일정 정보")) {
                    TextField("일정 제목 (예: 교육학 인강 듣기)", text: $title)
                    Picker("과목", selection: $selectedSubject) {
                        ForEach(subjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                }
                Section(header: Text("시간 설정")) {
                    DatePicker("시작", selection: $startDate, displayedComponents: [.hourAndMinute])
                    DatePicker("종료", selection: $endDate, displayedComponents: [.hourAndMinute])
                }
            }
            .navigationTitle("일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { saveSchedule() }.disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveSchedule() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 1번 파일(Model)이 수정되었다면 여기서 오류가 나지 않습니다.
        let newSchedule = ScheduleItem(
            title: title,
            startDate: startDate,
            endDate: endDate,
            subject: selectedSubject,
            isCompleted: false,
            ownerID: uid
        )
        modelContext.insert(newSchedule)
        dismiss()
    }
}

import SwiftUI
import SwiftData
import FirebaseAuth

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 타이머 상태 변수
    @State private var timeElapsed: Int = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var selectedSubject = "교직논술"
    
    // 초등 임용고시 과목 리스트
    let subjects = [
        "교직논술", "교육과정 총론", "창의적 체험활동",
        "국어", "수학", "사회", "과학", "영어",
        "도덕", "실과", "체육", "음악", "미술",
        "바른 생활", "슬기로운 생활", "즐거운 생활",
        "한국사", "교육학"
    ]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                
                // 1. 상단 여백
                Spacer().frame(height: 50)
                
                // 2. 과목 선택 영역 (수정됨 ✨)
                VStack(spacing: 15) {
                    Text("지금 공부할 과목")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Menu {
                        ForEach(subjects, id: \.self) { subject in
                            Button(subject) {
                                selectedSubject = subject
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedSubject)
                                .font(.title3) // 폰트 크기 키움
                                .fontWeight(.semibold)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(brandColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 25) // 좌우 여백 적당히
                        .background(Color.blue.opacity(0.1)) // 배경색
                        .clipShape(Capsule()) // 알약 모양으로 둥글게
                    }
                }
                
                Spacer()
                
                // 3. 타이머 시간 표시
                Text(formatTime(seconds: timeElapsed))
                    .font(.system(size: 90, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal)
                
                Spacer()
                
                // 4. 컨트롤 버튼
                HStack(spacing: 40) {
                    if isRunning {
                        Button(action: stopTimer) {
                            VStack {
                                Image(systemName: "pause.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                Text("일시정지")
                                    .font(.caption)
                                    .padding(.top, 5)
                            }
                        }
                        .foregroundColor(.orange)
                    } else {
                        Button(action: startTimer) {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                Text(timeElapsed > 0 ? "계속하기" : "시작")
                                    .font(.caption)
                                    .padding(.top, 5)
                            }
                        }
                        .foregroundColor(brandColor)
                    }
                    
                    if timeElapsed > 0 && !isRunning {
                        Button(action: saveRecord) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                Text("완료 및 저장")
                                    .font(.caption)
                                    .padding(.top, 5)
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
                .padding(.bottom, 20)
                
                // 5. 최근 기록 뷰 (삭제 기능 유지)
                RecentRecordsView(userId: currentUserId)
                    .padding(.bottom, 10)
            }
            .navigationTitle("집중 타이머")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: StatisticsView(userId: currentUserId)) {
                        Image(systemName: "chart.pie.fill")
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                }
            }
        }
    }
    
    func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeElapsed += 1
        }
    }
    
    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func saveRecord() {
        guard let user = Auth.auth().currentUser else { return }
        
        let newRecord = StudyRecord(
            durationSeconds: timeElapsed,
            areaName: selectedSubject,
            date: Date(),
            ownerID: user.uid
        )
        modelContext.insert(newRecord)
        timeElapsed = 0
        stopTimer()
    }
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

struct RecentRecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [StudyRecord]
    
    init(userId: String) {
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        }, sort: \.date, order: .reverse)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("최근 학습 기록")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 5)
            
            List {
                ForEach(records) { record in
                    HStack {
                        Text(record.areaName)
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        if record.durationSeconds >= 3600 {
                            Text("\(record.durationSeconds / 3600)시간 \((record.durationSeconds % 3600) / 60)분")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("\(record.durationSeconds / 60)분 \(record.durationSeconds % 60)초")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete(perform: deleteRecords)
            }
            .listStyle(.plain)
            .frame(height: 200)
        }
    }
    
    private func deleteRecords(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

#Preview {
    TimerView()
}

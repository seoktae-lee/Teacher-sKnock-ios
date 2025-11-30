import SwiftUI
import SwiftData
import FirebaseAuth // 인증 정보 사용

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var timeElapsed: Int = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var selectedSubject = "교육학"
    
    let subjects = ["교육학", "전공 A", "전공 B", "교직 논술", "한국사"]
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // ✨ 현재 로그인한 유저 ID 가져오기
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                
                VStack(spacing: 10) {
                    Text("지금 공부할 과목").font(.caption).foregroundColor(.gray)
                    Menu {
                        ForEach(subjects, id: \.self) { subject in
                            Button(subject) { selectedSubject = subject }
                        }
                    } label: {
                        HStack {
                            Text(selectedSubject).font(.headline)
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .foregroundColor(brandColor)
                        .padding(.vertical, 10).padding(.horizontal, 20)
                        .background(Color.blue.opacity(0.1)).cornerRadius(20)
                    }
                }
                .padding(.top, 30)
                
                Text(formatTime(seconds: timeElapsed))
                    .font(.system(size: 70, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary).padding()
                
                HStack(spacing: 30) {
                    if isRunning {
                        Button(action: stopTimer) {
                            VStack {
                                Image(systemName: "pause.circle.fill").resizable().frame(width: 70, height: 70)
                                Text("일시정지").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(.orange)
                    } else {
                        Button(action: startTimer) {
                            VStack {
                                Image(systemName: "play.circle.fill").resizable().frame(width: 70, height: 70)
                                Text(timeElapsed > 0 ? "계속하기" : "시작").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(brandColor)
                    }
                    
                    if timeElapsed > 0 && !isRunning {
                        Button(action: saveRecord) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill").resizable().frame(width: 70, height: 70)
                                Text("완료 및 저장").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // ✨ 최근 기록 뷰에도 ID 전달
                RecentRecordsView(userId: currentUserId)
            }
            .navigationTitle("집중 타이머")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // ✨ 통계 화면에도 ID 전달
                    NavigationLink(destination: StatisticsView(userId: currentUserId)) {
                        Image(systemName: "chart.pie.fill").font(.title3).foregroundColor(brandColor)
                    }
                }
            }
        }
    }
    
    func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in timeElapsed += 1 }
    }
    
    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func saveRecord() {
        guard let user = Auth.auth().currentUser else { return }
        
        // ✨ 저장 시 ownerID 포함
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

// 하위 뷰: 최근 학습 기록 (필터링 적용)
struct RecentRecordsView: View {
    @Query private var records: [StudyRecord]
    
    init(userId: String) {
        // ✨ 최근 5개만 가져오되, 내 ID 것만!
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        }, sort: \.date, order: .reverse)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("최근 학습 기록").font(.headline).padding(.horizontal).padding(.bottom, 5)
            List {
                // 상위 5개만 표시 (Query에서 limit 기능이 아직 제한적이어서 여기서 자름)
                ForEach(records.prefix(5)) { record in
                    HStack {
                        Text(record.areaName).font(.subheadline).bold()
                        Spacer()
                        if record.durationSeconds >= 3600 {
                            Text("\(record.durationSeconds / 3600)시간 \((record.durationSeconds % 3600) / 60)분").font(.caption).foregroundColor(.gray)
                        } else {
                            Text("\(record.durationSeconds / 60)분 \(record.durationSeconds % 60)초").font(.caption).foregroundColor(.gray)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: 200)
        }
    }
}

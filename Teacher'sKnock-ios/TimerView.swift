import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 타이머 상태 변수
    @State private var timeElapsed: Int = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var selectedSubject = "교육학" // 기본 과목
    
    // 과목 리스트
    let subjects = ["교육학", "전공 A", "전공 B", "교직 논술", "한국사"]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                
                // 1. 과목 선택 (디자인 개선)
                VStack(spacing: 10) {
                    Text("지금 공부할 과목")
                        .font(.caption)
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
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(brandColor)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 30)
                
                // 2. 타이머 시간 표시
                Text(formatTime(seconds: timeElapsed))
                    .font(.system(size: 70, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding()
                
                // 3. 컨트롤 버튼
                HStack(spacing: 30) {
                    if isRunning {
                        // 정지 버튼
                        Button(action: stopTimer) {
                            VStack {
                                Image(systemName: "pause.circle.fill")
                                    .resizable()
                                    .frame(width: 70, height: 70)
                                Text("일시정지")
                                    .font(.caption)
                                    .padding(.top, 5)
                            }
                        }
                        .foregroundColor(.orange)
                    } else {
                        // 시작 버튼
                        Button(action: startTimer) {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .resizable()
                                    .frame(width: 70, height: 70)
                                Text(timeElapsed > 0 ? "계속하기" : "시작")
                                    .font(.caption)
                                    .padding(.top, 5)
                            }
                        }
                        .foregroundColor(brandColor)
                    }
                    
                    // 저장 버튼 (시간이 있을 때만 표시)
                    if timeElapsed > 0 && !isRunning {
                        Button(action: saveRecord) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 70, height: 70)
                                Text("완료 및 저장")
                                    .font(.caption)
                                    .padding(.top, 5)
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // 4. 최근 기록 뷰
                RecentRecordsView()
            }
            .navigationTitle("집중 타이머")
            // ✨ [핵심] 통계 화면으로 이동하는 버튼 추가
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: StatisticsView()) {
                        Image(systemName: "chart.pie.fill") // 파이 차트 아이콘
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                }
            }
        }
    }
    
    // --- 로직 함수들 ---
    
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
        let newRecord = StudyRecord(durationSeconds: timeElapsed, areaName: selectedSubject, date: Date())
        modelContext.insert(newRecord)
        
        // 저장 후 초기화
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

// 하위 뷰: 최근 학습 기록
struct RecentRecordsView: View {
    @Query(sort: \StudyRecord.date, order: .reverse) private var records: [StudyRecord]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("최근 학습 기록")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 5)
            
            List {
                ForEach(records.prefix(5)) { record in
                    HStack {
                        Text(record.areaName)
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        // 1시간 이상이면 시간 단위, 아니면 분/초 단위 표시
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
            }
            .listStyle(.plain)
            .frame(height: 200)
        }
    }
}

#Preview {
    TimerView()
}

import SwiftUI
import SwiftData
import FirebaseAuth

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    
    // 1. 타이머 관련 변수
    @State private var startTime: Date?             // 시작 시각 (기준점)
    @State private var accumulatedTime: TimeInterval = 0 // 일시정지 전까지 저장된 시간
    @State private var timer: Timer?                // 타이머 객체
    @State private var isRunning = false            // 실행 중 여부
    
    // ✨ [수정] 화면에 보여줄 시간을 저장하는 변수 (이게 변해야 화면이 바뀜!)
    @State private var displayTime: Int = 0
    
    // 선택 값들
    @State private var selectedSubject: String = "교육학"
    @State private var selectedPurpose: StudyPurpose = .lectureWatching
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                
                Spacer().frame(height: 30)
                
                // 1. 과목 및 목적 선택 영역
                HStack(spacing: 15) {
                    // 과목 선택 메뉴
                    VStack(spacing: 8) {
                        Text("과목")
                            .font(.caption).foregroundColor(.gray)
                        
                        Menu {
                            ForEach(settingsManager.favoriteSubjects) { subject in
                                Button(subject.localizedName) {
                                    selectedSubject = subject.localizedName
                                }
                            }
                            Divider()
                            NavigationLink(destination: SubjectSelectView()) {
                                Label("과목 설정 편집", systemImage: "gearshape")
                            }
                        } label: {
                            HStack {
                                Text(selectedSubject)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                Image(systemName: "chevron.down").font(.caption)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(15)
                        }
                    }
                    
                    // 공부 목적 선택 메뉴
                    VStack(spacing: 8) {
                        Text("공부 목적")
                            .font(.caption).foregroundColor(.gray)
                        
                        Menu {
                            ForEach(StudyPurpose.orderedCases, id: \.self) { purpose in
                                Button(purpose.localizedName) {
                                    selectedPurpose = purpose
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedPurpose.localizedName)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                Image(systemName: "chevron.down").font(.caption)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(15)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .disabled(isRunning)
                .opacity(isRunning ? 0.6 : 1.0)
                
                Spacer()
                
                // 2. 타이머 시간 표시 (displayTime 사용)
                Text(formatTime(seconds: displayTime))
                    .font(.system(size: 90, weight: .medium, design: .monospaced))
                    .foregroundColor(isRunning ? brandColor : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal)
                
                Spacer()
                
                // 3. 컨트롤 버튼
                HStack(spacing: 40) {
                    if isRunning {
                        Button(action: stopTimer) {
                            VStack {
                                Image(systemName: "pause.circle.fill").resizable().frame(width: 80, height: 80)
                                Text("일시정지").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(.orange)
                    } else {
                        Button(action: startTimer) {
                            VStack {
                                Image(systemName: "play.circle.fill").resizable().frame(width: 80, height: 80)
                                Text(displayTime > 0 ? "계속하기" : "시작").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(brandColor)
                    }
                    
                    // 저장 버튼
                    if !isRunning && displayTime > 0 {
                        Button(action: saveRecord) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill").resizable().frame(width: 80, height: 80)
                                Text("완료 및 저장").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
                .padding(.bottom, 20)
                
                // 4. 최근 기록 뷰
                RecentRecordsView(userId: currentUserId)
                    .padding(.bottom, 10)
            }
            .navigationTitle("집중 타이머")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: StatisticsView(userId: currentUserId)) {
                        Image(systemName: "chart.pie.fill").font(.title3).foregroundColor(brandColor)
                    }
                }
            }
            .onAppear {
                setupInitialSubject()
                // 화면에 다시 돌아왔을 때, 혹시 멈춰있는 시간이 있으면 표시 업데이트
                if !isRunning {
                    displayTime = Int(accumulatedTime)
                }
            }
            .onDisappear {
                if isRunning { stopTimer() }
            }
        }
    }
    
    private func setupInitialSubject() {
        if let first = settingsManager.favoriteSubjects.first {
            if !settingsManager.favoriteSubjects.contains(where: { $0.localizedName == selectedSubject }) {
                selectedSubject = first.localizedName
            }
        }
    }
    
    // ✨ 타이머 시작 (수정됨)
    func startTimer() {
        startTime = Date()
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 0.1초마다 반복하며 '현재 흐른 시간'을 계산해서 displayTime에 넣음
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateDisplayTime()
        }
    }
    
    // ✨ 화면 갱신 함수 (핵심)
    func updateDisplayTime() {
        guard let start = startTime else { return }
        let current = Date().timeIntervalSince(start)
        let total = current + accumulatedTime
        
        // 소수점 버리고 정수형으로 화면 업데이트
        self.displayTime = Int(total)
    }
    
    // ✨ 타이머 정지
    func stopTimer() {
        if let start = startTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        
        // 정지 시점의 시간을 최종적으로 한 번 더 업데이트
        displayTime = Int(accumulatedTime)
        
        startTime = nil
        isRunning = false
        timer?.invalidate()
        timer = nil
        
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func saveRecord() {
        guard let user = Auth.auth().currentUser else { return }
        
        let finalTime = displayTime
        if finalTime < 5 { return }
        
        let newRecord = StudyRecord(
            durationSeconds: finalTime,
            areaName: selectedSubject,
            date: Date(),
            ownerID: user.uid,
            studyPurpose: selectedPurpose.rawValue
        )
        modelContext.insert(newRecord)
        
        // 저장 후 완전 초기화
        stopTimer()
        accumulatedTime = 0
        displayTime = 0 // 화면도 0으로 복귀
    }
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// RecentRecordsView는 기존과 동일하므로 생략하지 않고, 안전을 위해 함께 포함 (변경 없음)
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
            Text("최근 학습 기록").font(.headline).padding(.horizontal).padding(.bottom, 5)
            
            List {
                ForEach(records.prefix(10)) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.areaName)
                                .font(.subheadline)
                                .bold()
                            Text(record.studyPurpose)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        Spacer()
                        if record.durationSeconds >= 3600 {
                            Text("\(record.durationSeconds / 3600)시간 \((record.durationSeconds % 3600) / 60)분")
                                .font(.caption).foregroundColor(.gray)
                        } else {
                            Text("\(record.durationSeconds / 60)분 \(record.durationSeconds % 60)초")
                                .font(.caption).foregroundColor(.gray)
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
        .environmentObject(SettingsManager())
}

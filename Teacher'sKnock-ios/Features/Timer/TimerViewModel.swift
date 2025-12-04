import Foundation
import SwiftUI
import SwiftData
import Combine

class TimerViewModel: ObservableObject {
    
    // MARK: - 화면과 공유하는 데이터 (Published)
    @Published var isRunning: Bool = false
    @Published var displayTime: Int = 0
    @Published var selectedSubject: String = "교육학"
    @Published var selectedPurpose: StudyPurpose = .lectureWatching
    
    // MARK: - 내부 로직용 변수 (Private)
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var timer: Timer?
    
    // MARK: - 로직 함수들
    
    func startTimer() {
        startTime = Date()
        isRunning = true
        // 화면 꺼짐 방지
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 0.1초마다 시간 갱신
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDisplayTime()
        }
    }
    
    func stopTimer() {
        if let start = startTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        displayTime = Int(accumulatedTime)
        startTime = nil
        isRunning = false
        
        timer?.invalidate()
        timer = nil
        
        // 화면 꺼짐 방지 해제
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func updateDisplayTime() {
        guard let start = startTime else { return }
        let current = Date().timeIntervalSince(start)
        let total = current + accumulatedTime
        self.displayTime = Int(total)
    }
    
    // 기록 저장 로직
    func saveRecord(context: ModelContext, ownerID: String) {
        let finalTime = displayTime
        
        // 5초 미만은 저장 안 함
        if finalTime < 5 { return }
        
        let newRecord = StudyRecord(
            durationSeconds: finalTime,
            areaName: selectedSubject,
            date: Date(),
            ownerID: ownerID,
            studyPurpose: selectedPurpose.rawValue
        )
        
        // 1. 로컬 저장 (SwiftData)
        context.insert(newRecord)
        
        // 2. 서버 저장 (Firestore 백업)
        FirestoreSyncManager.shared.saveRecord(newRecord)
        
        print("TimerVM: 공부 기록 저장 완료 - \(selectedSubject) \(finalTime)초")
        
        // 저장 후 초기화
        stopTimer()
        accumulatedTime = 0
        displayTime = 0
    }
    
    // 시간 포맷팅 (00:00:00)
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    // 초기 과목 설정 (설정된 선호 과목이 있으면 첫 번째꺼 선택)
    func setupInitialSubject(favorites: [SubjectName]) {
        // 이미 선택된 게 목록에 없거나 초기 상태라면, 즐겨찾기 첫 번째로 설정
        if let first = favorites.first,
           !favorites.contains(where: { $0.localizedName == selectedSubject }) {
            selectedSubject = first.localizedName
        }
    }
}

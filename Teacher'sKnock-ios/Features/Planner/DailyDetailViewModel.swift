import Foundation
import SwiftData
import SwiftUI
import Combine

class DailyDetailViewModel: ObservableObject {
    private var modelContext: ModelContext?
    let userId: String
    let targetDate: Date
    
    // 뷰에서 감시할 데이터들
    @Published var schedules: [ScheduleItem] = []
    @Published var records: [StudyRecord] = []
    
    // 파이차트용 데이터 구조체 (ViewModel 내부에 정의하거나 외부로 빼도 됨)
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        var color: Color {
            if let matched = SubjectName.allCases.first(where: { $0.rawValue == subject }) { return matched.color }
            return .gray
        }
    }
    
    init(userId: String, targetDate: Date) {
        self.userId = userId
        self.targetDate = targetDate
    }
    
    // 뷰가 나타날 때(onAppear) 컨텍스트 주입받고 데이터 로드
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        fetchData()
    }
    
    func fetchData() {
        guard let context = modelContext else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // 1. 일정(Schedule) 가져오기
        let scheduleDescriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { item in
                item.ownerID == userId && item.startDate >= startOfDay && item.startDate < endOfDay
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        
        // 2. 공부기록(Record) 가져오기
        let recordDescriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate { record in
                record.ownerID == userId && record.date >= startOfDay && record.date < endOfDay
            }
        )
        
        do {
            self.schedules = try context.fetch(scheduleDescriptor)
            self.records = try context.fetch(recordDescriptor)
        } catch {
            print("데이터 로드 실패: \(error)")
        }
    }
    
    // 파이차트 데이터 계산
    var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records { dict[record.areaName, default: 0] += record.durationSeconds }
        return dict.map { ChartData(subject: $0.key, seconds: $0.value) }
    }
    
    var totalActualSeconds: Int { pieData.reduce(0) { $0 + $1.seconds } }
    
    // 날짜 포맷팅
    var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 (EEEE)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: targetDate)
    }
    
    // MARK: - 비즈니스 로직 (User Intents)
    
    func duplicateToTomorrow(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        
        let oneDaySeconds: TimeInterval = 86400
        let newStart = item.startDate.addingTimeInterval(oneDaySeconds)
        let newEnd = item.endDate?.addingTimeInterval(oneDaySeconds)
        
        let newItem = ScheduleItem(
            title: item.title,
            details: item.details,
            startDate: newStart,
            endDate: newEnd,
            isCompleted: false,
            hasReminder: item.hasReminder,
            ownerID: item.ownerID,
            isPostponed: false
        )
        
        context.insert(newItem)
        
        // 싱크 매니저 호출 (옵셔널 바인딩이나 싱글톤 직접 호출)
        FirestoreSyncManager.shared.saveSchedule(newItem)
        
        // 원본 상태 변경
        item.isPostponed = true
        item.isCompleted = false
        
        // 변경사항 저장 및 데이터 새로고침
        saveContext()
        fetchData()
    }
    
    func deleteSchedule(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        context.delete(item)
        saveContext()
        fetchData()
    }
    
    func toggleComplete(_ item: ScheduleItem) {
        if !item.isPostponed {
            item.isCompleted.toggle()
            // 변경 즉시 저장은 선택 사항이나, UX상 바로 반영되는 게 좋음
            saveContext()
        }
    }
    
    private func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            print("저장 실패: \(error)")
        }
    }
}
